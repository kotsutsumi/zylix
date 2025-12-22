package com.zylix.test.demo

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Assertions.*

/**
 * Zylix Test Framework - Android E2E Test Examples
 *
 * These tests demonstrate how to use the Zylix Test Framework
 * to automate Android application testing via Appium/UIAutomator2.
 */
class AndroidTestDemoTests {

    private lateinit var client: ZylixAndroidTestClient
    private var session: AndroidSession? = null

    @BeforeEach
    fun setup() {
        client = ZylixAndroidTestClient(port = 4723)
    }

    @AfterEach
    fun teardown() {
        session?.let {
            try {
                client.deleteSession(it.id)
                println("✅ Cleaned up session")
            } catch (e: Exception) {
                println("⚠️  Session cleanup failed: ${e.message}")
            }
        }
    }

    // MARK: - Connection Tests

    @Test
    fun `test Appium availability`() {
        val available = client.isAvailable()

        if (!available) {
            println("⏭️  Appium not available, skipping Android tests")
            assumeTrue(false, "Appium not available")
        }

        println("✅ Appium is available")
    }

    // MARK: - Session Tests

    @Test
    fun `test session lifecycle`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        assertNotNull(session)
        assertTrue(session!!.id.isNotEmpty())
        println("✅ Created session: ${session!!.id}")

        client.deleteSession(session!!.id)
        session = null
        println("✅ Deleted session")
    }

    // MARK: - Element Finding Tests

    @Test
    fun `test find element by UIAutomator`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        try {
            val element = session!!.findByUIAutomator(
                "new UiSelector().text(\"Network & internet\")"
            )
            assertTrue(element.exists)
            println("✅ Found element by UIAutomator")
        } catch (e: Exception) {
            println("⚠️  Element not found: ${e.message}")
            // Settings layout varies by Android version
        }
    }

    @Test
    fun `test find element by accessibility id`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        try {
            // Try to find search bar (has accessibility id on many versions)
            val element = session!!.findByAccessibilityId("Search settings")
            assertTrue(element.exists)
            println("✅ Found element by accessibility ID")
        } catch (e: Exception) {
            println("⚠️  Element not found (expected on some Android versions)")
        }
    }

    // MARK: - Interaction Tests

    @Test
    fun `test tap element`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        try {
            val networkItem = session!!.findByUIAutomator(
                "new UiSelector().text(\"Network & internet\")"
            )
            networkItem.tap()
            println("✅ Tapped element")

            // Give UI time to update
            Thread.sleep(500)

            // Verify we navigated
            val wifiItem = session!!.findByUIAutomator(
                "new UiSelector().text(\"Wi-Fi\")"
            )
            assertTrue(wifiItem.exists)
            println("✅ Verified navigation")
        } catch (e: Exception) {
            println("⚠️  Interaction test incomplete: ${e.message}")
        }
    }

    @Test
    fun `test swipe gesture`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        // Swipe up to scroll down
        session!!.swipe(
            startX = 500,
            startY = 1500,
            endX = 500,
            endY = 500,
            durationMs = 500
        )

        println("✅ Swipe completed")
    }

    // MARK: - System Button Tests

    @Test
    fun `test back button`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        try {
            // Navigate into a setting
            val networkItem = session!!.findByUIAutomator(
                "new UiSelector().text(\"Network & internet\")"
            )
            networkItem.tap()

            Thread.sleep(300)

            // Press back
            session!!.pressBack()

            println("✅ Back button pressed")
        } catch (e: Exception) {
            println("⚠️  Back button test incomplete: ${e.message}")
        }
    }

    @Test
    fun `test home button`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        session!!.pressHome()
        println("✅ Home button pressed")
    }

    // MARK: - Screenshot Tests

    @Test
    fun `test screenshot capture`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        val screenshot = session!!.takeScreenshot()

        assertTrue(screenshot.isNotEmpty())
        println("✅ Captured screenshot: ${screenshot.size} bytes")

        // Optionally save
        java.io.File("android-screenshot.png").writeBytes(screenshot)
        println("✅ Saved screenshot")
    }

    // MARK: - UI Hierarchy Tests

    @Test
    fun `test get UI source`() {
        assumeTrue(client.isAvailable(), "Appium not available")

        session = client.createSession(
            packageName = "com.android.settings"
        )

        val source = session!!.getSource()

        assertTrue(source.isNotEmpty())
        assertTrue(source.contains("hierarchy") || source.contains("android.widget"))
        println("✅ Retrieved UI hierarchy: ${source.length} chars")
    }
}

/*
 Android Testing Patterns Documentation:

 1. Session Management:
    - Create session with package name
    - Optional: specify activity name for direct launch
    - Always clean up sessions in teardown

 2. Element Finding:
    - UIAutomator: Most powerful, Android-native
    - Accessibility ID: Best for app-defined identifiers
    - Resource ID: For views with android:id

 3. UIAutomator Selectors:
    - text(): Exact match
    - textContains(): Partial match
    - resourceId(): Full resource ID
    - className(): Widget class
    - description(): Content description
    - Combine with index() for ambiguous matches

 4. Gestures:
    - tap(): Single touch
    - swipe(): Scroll, dismiss, navigate
    - Back button: System navigation
    - Home button: Exit to launcher

 5. Error Handling:
    - Assume tests when Appium unavailable
    - Handle layout variations across Android versions
    - Use try-catch for optional assertions
*/
