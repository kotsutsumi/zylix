package com.zylix.test.demo

import java.net.HttpURLConnection
import java.net.URI
import org.json.JSONObject

/**
 * Zylix Test Framework - Android Client
 * Connects to Appium/UIAutomator2 for E2E testing
 */
class ZylixAndroidTestClient(
    private val host: String = "127.0.0.1",
    private val port: Int = 4723
) {
    /**
     * Check if Appium server is available
     */
    fun isAvailable(): Boolean {
        return try {
            val url = URI("http://$host:$port/status").toURL()
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 1000
            connection.readTimeout = 1000
            connection.responseCode == 200
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Create a new Android session
     */
    fun createSession(
        packageName: String,
        activityName: String? = null,
        platformVersion: String = "14",
        deviceName: String = "Android Emulator"
    ): AndroidSession {
        val url = URI("http://$host:$port/session").toURL()
        val connection = url.openConnection() as HttpURLConnection

        connection.requestMethod = "POST"
        connection.setRequestProperty("Content-Type", "application/json")
        connection.doOutput = true

        val capabilities = JSONObject().apply {
            put("capabilities", JSONObject().apply {
                put("alwaysMatch", JSONObject().apply {
                    put("platformName", "Android")
                    put("platformVersion", platformVersion)
                    put("deviceName", deviceName)
                    put("automationName", "UiAutomator2")
                    put("appPackage", packageName)
                    if (activityName != null) {
                        put("appActivity", activityName)
                    }
                })
            })
        }

        connection.outputStream.write(capabilities.toString().toByteArray())

        val response = connection.inputStream.bufferedReader().readText()
        val json = JSONObject(response)
        val value = json.getJSONObject("value")
        val sessionId = value.getString("sessionId")

        return AndroidSession(sessionId, this)
    }

    /**
     * Delete a session
     */
    fun deleteSession(sessionId: String) {
        val url = URI("http://$host:$port/session/$sessionId").toURL()
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "DELETE"
        connection.responseCode // Force execution
    }

    internal fun sendRequest(
        method: String,
        path: String,
        body: String? = null
    ): String {
        val url = URI("http://$host:$port$path").toURL()
        val connection = url.openConnection() as HttpURLConnection

        connection.requestMethod = method
        connection.setRequestProperty("Content-Type", "application/json")

        if (body != null) {
            connection.doOutput = true
            connection.outputStream.write(body.toByteArray())
        }

        return connection.inputStream.bufferedReader().readText()
    }
}

/**
 * Android test session
 */
class AndroidSession(
    val id: String,
    private val client: ZylixAndroidTestClient
) {
    /**
     * Find element by UIAutomator selector
     */
    fun findByUIAutomator(selector: String): AndroidElement {
        val body = JSONObject().apply {
            put("using", "-android uiautomator")
            put("value", selector)
        }

        val response = client.sendRequest(
            "POST",
            "/session/$id/element",
            body.toString()
        )

        val json = JSONObject(response)
        val value = json.getJSONObject("value")
        val elementId = value.getString("ELEMENT")

        return AndroidElement(elementId, id, client)
    }

    /**
     * Find element by accessibility ID
     */
    fun findByAccessibilityId(accessibilityId: String): AndroidElement {
        val body = JSONObject().apply {
            put("using", "accessibility id")
            put("value", accessibilityId)
        }

        val response = client.sendRequest(
            "POST",
            "/session/$id/element",
            body.toString()
        )

        val json = JSONObject(response)
        val value = json.getJSONObject("value")
        val elementId = value.getString("ELEMENT")

        return AndroidElement(elementId, id, client)
    }

    /**
     * Find element by resource ID
     */
    fun findByResourceId(resourceId: String): AndroidElement {
        return findByUIAutomator("new UiSelector().resourceId(\"$resourceId\")")
    }

    /**
     * Press back button
     */
    fun pressBack() {
        client.sendRequest("POST", "/session/$id/back", "{}")
    }

    /**
     * Press home button
     */
    fun pressHome() {
        val body = JSONObject().apply {
            put("keycode", 3) // KEYCODE_HOME
        }
        client.sendRequest("POST", "/session/$id/appium/device/press_keycode", body.toString())
    }

    /**
     * Swipe gesture
     */
    fun swipe(
        startX: Int,
        startY: Int,
        endX: Int,
        endY: Int,
        durationMs: Int = 500
    ) {
        val body = JSONObject().apply {
            put("actions", org.json.JSONArray().apply {
                put(JSONObject().apply {
                    put("type", "pointer")
                    put("id", "finger1")
                    put("parameters", JSONObject().put("pointerType", "touch"))
                    put("actions", org.json.JSONArray().apply {
                        put(JSONObject().apply {
                            put("type", "pointerMove")
                            put("duration", 0)
                            put("x", startX)
                            put("y", startY)
                        })
                        put(JSONObject().apply {
                            put("type", "pointerDown")
                            put("button", 0)
                        })
                        put(JSONObject().apply {
                            put("type", "pointerMove")
                            put("duration", durationMs)
                            put("x", endX)
                            put("y", endY)
                        })
                        put(JSONObject().apply {
                            put("type", "pointerUp")
                            put("button", 0)
                        })
                    })
                })
            })
        }

        client.sendRequest("POST", "/session/$id/actions", body.toString())
    }

    /**
     * Take screenshot
     */
    fun takeScreenshot(): ByteArray {
        val response = client.sendRequest("GET", "/session/$id/screenshot")
        val json = JSONObject(response)
        val base64 = json.getString("value")
        return java.util.Base64.getDecoder().decode(base64)
    }

    /**
     * Get UI hierarchy source
     */
    fun getSource(): String {
        val response = client.sendRequest("GET", "/session/$id/source")
        val json = JSONObject(response)
        return json.getString("value")
    }
}

/**
 * Android element
 */
class AndroidElement(
    val id: String,
    private val sessionId: String,
    private val client: ZylixAndroidTestClient
) {
    val exists: Boolean get() = id.isNotEmpty()

    /**
     * Tap the element
     */
    fun tap() {
        client.sendRequest(
            "POST",
            "/session/$sessionId/element/$id/click",
            "{}"
        )
    }

    /**
     * Get element text
     */
    fun getText(): String {
        val response = client.sendRequest(
            "GET",
            "/session/$sessionId/element/$id/text"
        )
        val json = JSONObject(response)
        return json.optString("value", "")
    }

    /**
     * Send keys to element
     */
    fun sendKeys(text: String) {
        val body = JSONObject().apply {
            put("text", text)
        }
        client.sendRequest(
            "POST",
            "/session/$sessionId/element/$id/value",
            body.toString()
        )
    }

    /**
     * Clear element text
     */
    fun clear() {
        client.sendRequest(
            "POST",
            "/session/$sessionId/element/$id/clear",
            "{}"
        )
    }

    /**
     * Check if element is displayed
     */
    fun isDisplayed(): Boolean {
        val response = client.sendRequest(
            "GET",
            "/session/$sessionId/element/$id/displayed"
        )
        val json = JSONObject(response)
        return json.optBoolean("value", false)
    }
}
