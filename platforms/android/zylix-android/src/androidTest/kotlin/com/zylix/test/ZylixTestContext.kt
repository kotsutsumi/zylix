package com.zylix.test

import android.app.Activity
import android.content.Intent
import android.view.View
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.UiController
import androidx.test.espresso.ViewAction
import androidx.test.espresso.ViewInteraction
import androidx.test.espresso.action.ViewActions
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.hamcrest.Matcher
import org.hamcrest.Matchers.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Application state for E2E testing
 */
enum class ZylixTestAppState {
    IDLE,
    LOADING,
    READY,
    ERROR,
    UNKNOWN
}

/**
 * Configuration for Zylix E2E tests
 */
data class ZylixTestConfig(
    /** Default timeout for waiting operations (ms) */
    val defaultTimeout: Long = 10_000L,

    /** Screenshot capture on failure */
    val captureScreenshotOnFailure: Boolean = true,

    /** Log level for test output */
    val logLevel: LogLevel = LogLevel.INFO,

    /** Reset app state before each test */
    val resetStateBeforeTest: Boolean = true
) {
    enum class LogLevel(val level: Int) {
        NONE(0),
        ERROR(1),
        WARNING(2),
        INFO(3),
        DEBUG(4)
    }
}

/**
 * Swipe direction for gestures
 */
enum class SwipeDirection {
    UP, DOWN, LEFT, RIGHT
}

/**
 * Main testing context for Zylix E2E tests on Android.
 *
 * Provides unified testing helpers for Espresso integration.
 *
 * @param activityClass The activity class to launch for testing
 * @param config Test configuration options
 */
class ZylixTestContext<T : Activity>(
    private val activityClass: Class<T>,
    val config: ZylixTestConfig = ZylixTestConfig()
) {
    private var scenario: ActivityScenario<T>? = null
    private var currentState: ZylixTestAppState = ZylixTestAppState.UNKNOWN
    private val screenshots: MutableList<File> = mutableListOf()
    private val uiDevice: UiDevice by lazy {
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    // MARK: - App Lifecycle

    /**
     * Launch the activity with optional intent extras
     */
    fun launch(
        intentExtras: Map<String, Any> = emptyMap(),
        launchFlags: Int? = null
    ) {
        val intent = Intent(ApplicationProvider.getApplicationContext(), activityClass).apply {
            intentExtras.forEach { (key, value) ->
                when (value) {
                    is String -> putExtra(key, value)
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                    is Boolean -> putExtra(key, value)
                    is Float -> putExtra(key, value)
                    is Double -> putExtra(key, value)
                }
            }
            launchFlags?.let { flags = it }

            if (config.resetStateBeforeTest) {
                putExtra("--reset-state", true)
            }
        }

        scenario = ActivityScenario.launch(intent)
        log("Activity launched", ZylixTestConfig.LogLevel.INFO)
    }

    /**
     * Close the activity
     */
    fun close() {
        scenario?.close()
        scenario = null
        log("Activity closed", ZylixTestConfig.LogLevel.INFO)
    }

    /**
     * Verify that Zylix core is initialized
     */
    fun verifyInitialization(timeout: Long? = null): Boolean {
        val timeoutValue = timeout ?: config.defaultTimeout
        val startTime = System.currentTimeMillis()

        while (System.currentTimeMillis() - startTime < timeoutValue) {
            try {
                // Wait for activity to be in resumed state
                scenario?.onActivity { activity ->
                    if (activity.window.decorView.isShown) {
                        currentState = ZylixTestAppState.READY
                    }
                }

                if (currentState == ZylixTestAppState.READY) {
                    log("Zylix core initialized successfully", ZylixTestConfig.LogLevel.INFO)
                    return true
                }
            } catch (e: Exception) {
                log("Initialization check error: ${e.message}", ZylixTestConfig.LogLevel.DEBUG)
            }

            Thread.sleep(100)
        }

        currentState = ZylixTestAppState.ERROR
        log("Zylix core initialization failed", ZylixTestConfig.LogLevel.ERROR)
        return false
    }

    /**
     * Get current app state
     */
    fun getState(): ZylixTestAppState = currentState

    // MARK: - Interaction Helpers

    /**
     * Simulate tap at coordinates
     */
    fun simulateTap(x: Float, y: Float) {
        uiDevice.click(x.toInt(), y.toInt())
        log("Tap at ($x, $y)", ZylixTestConfig.LogLevel.DEBUG)
    }

    /**
     * Tap on view matching the given matcher
     */
    fun tap(viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher).perform(ViewActions.click()).also {
            log("Tapped view", ZylixTestConfig.LogLevel.DEBUG)
        }
    }

    /**
     * Tap on view with specific ID
     */
    fun tapById(viewId: Int, timeout: Long? = null): ViewInteraction {
        return tap(withId(viewId), timeout)
    }

    /**
     * Tap on view with specific text
     */
    fun tapByText(text: String, timeout: Long? = null): ViewInteraction {
        return tap(withText(text), timeout)
    }

    /**
     * Tap on view with content description
     */
    fun tapByContentDescription(description: String, timeout: Long? = null): ViewInteraction {
        return tap(withContentDescription(description), timeout)
    }

    /**
     * Double tap on view
     */
    fun doubleTap(viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher).perform(ViewActions.doubleClick()).also {
            log("Double tapped view", ZylixTestConfig.LogLevel.DEBUG)
        }
    }

    /**
     * Long press on view
     */
    fun longPress(viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher).perform(ViewActions.longClick()).also {
            log("Long pressed view", ZylixTestConfig.LogLevel.DEBUG)
        }
    }

    /**
     * Swipe gesture on view
     */
    fun swipe(direction: SwipeDirection, viewMatcher: Matcher<View>? = null): ViewInteraction {
        val target = viewMatcher ?: isRoot()
        val action = when (direction) {
            SwipeDirection.UP -> ViewActions.swipeUp()
            SwipeDirection.DOWN -> ViewActions.swipeDown()
            SwipeDirection.LEFT -> ViewActions.swipeLeft()
            SwipeDirection.RIGHT -> ViewActions.swipeRight()
        }
        return onView(target).perform(action).also {
            log("Swiped $direction", ZylixTestConfig.LogLevel.DEBUG)
        }
    }

    /**
     * Type text into view
     */
    fun typeText(text: String, viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher)
            .perform(ViewActions.click())
            .perform(ViewActions.typeText(text))
            .also {
                log("Typed text into view", ZylixTestConfig.LogLevel.DEBUG)
            }
    }

    /**
     * Type text into view by ID
     */
    fun typeTextById(text: String, viewId: Int, timeout: Long? = null): ViewInteraction {
        return typeText(text, withId(viewId), timeout)
    }

    /**
     * Clear text in view
     */
    fun clearText(viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher)
            .perform(ViewActions.click())
            .perform(ViewActions.clearText())
            .also {
                log("Cleared text in view", ZylixTestConfig.LogLevel.DEBUG)
            }
    }

    /**
     * Replace text in view
     */
    fun replaceText(text: String, viewMatcher: Matcher<View>, timeout: Long? = null): ViewInteraction {
        waitForView(viewMatcher, timeout)
        return onView(viewMatcher)
            .perform(ViewActions.replaceText(text))
            .also {
                log("Replaced text in view", ZylixTestConfig.LogLevel.DEBUG)
            }
    }

    /**
     * Close soft keyboard
     */
    fun closeKeyboard() {
        Espresso.closeSoftKeyboard()
        log("Closed keyboard", ZylixTestConfig.LogLevel.DEBUG)
    }

    /**
     * Press back button
     */
    fun pressBack() {
        Espresso.pressBack()
        log("Pressed back", ZylixTestConfig.LogLevel.DEBUG)
    }

    // MARK: - Wait Helpers

    /**
     * Wait for view to be visible
     */
    fun waitForView(
        viewMatcher: Matcher<View>,
        timeout: Long? = null
    ): Boolean {
        val timeoutValue = timeout ?: config.defaultTimeout
        val startTime = System.currentTimeMillis()

        while (System.currentTimeMillis() - startTime < timeoutValue) {
            try {
                onView(viewMatcher).check(matches(isDisplayed()))
                return true
            } catch (e: Exception) {
                Thread.sleep(100)
            }
        }

        log("Timeout waiting for view", ZylixTestConfig.LogLevel.WARNING)
        return false
    }

    /**
     * Wait for view to disappear
     */
    fun waitForViewToDisappear(
        viewMatcher: Matcher<View>,
        timeout: Long? = null
    ): Boolean {
        val timeoutValue = timeout ?: config.defaultTimeout
        val startTime = System.currentTimeMillis()

        while (System.currentTimeMillis() - startTime < timeoutValue) {
            try {
                onView(viewMatcher).check(matches(not(isDisplayed())))
                return true
            } catch (e: Exception) {
                // View is still visible
                try {
                    onView(viewMatcher).check(matches(isDisplayed()))
                    Thread.sleep(100)
                } catch (e2: Exception) {
                    // View doesn't exist, which means it's disappeared
                    return true
                }
            }
        }

        log("Timeout waiting for view to disappear", ZylixTestConfig.LogLevel.WARNING)
        return false
    }

    /**
     * Wait for state change
     */
    fun waitForStateChange(
        targetState: ZylixTestAppState,
        timeout: Long? = null
    ): Boolean {
        val timeoutValue = timeout ?: config.defaultTimeout
        val startTime = System.currentTimeMillis()

        while (System.currentTimeMillis() - startTime < timeoutValue) {
            if (getState() == targetState) {
                log("State changed to $targetState", ZylixTestConfig.LogLevel.DEBUG)
                return true
            }
            Thread.sleep(100)
        }

        log("Timeout waiting for state: $targetState", ZylixTestConfig.LogLevel.WARNING)
        return false
    }

    /**
     * Wait for specific duration
     */
    fun waitFor(milliseconds: Long) {
        Thread.sleep(milliseconds)
    }

    /**
     * Idle sync - wait for all pending tasks to complete
     */
    fun idleSync() {
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
    }

    // MARK: - View Query Helpers

    /**
     * Check if view with ID exists
     */
    fun viewExists(viewId: Int): Boolean {
        return try {
            onView(withId(viewId)).check(matches(isDisplayed()))
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if view with text exists
     */
    fun viewWithTextExists(text: String): Boolean {
        return try {
            onView(withText(text)).check(matches(isDisplayed()))
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get view interaction by ID
     */
    fun view(viewId: Int): ViewInteraction = onView(withId(viewId))

    /**
     * Get view interaction by text
     */
    fun viewWithText(text: String): ViewInteraction = onView(withText(text))

    /**
     * Get view interaction by content description
     */
    fun viewWithDescription(description: String): ViewInteraction =
        onView(withContentDescription(description))

    /**
     * Get view with tag
     */
    fun viewWithTag(tag: Any): ViewInteraction = onView(withTagValue(`is`(tag)))

    // MARK: - Assertion Helpers

    /**
     * Assert view is displayed
     */
    fun assertDisplayed(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(isDisplayed()))
    }

    /**
     * Assert view with ID is displayed
     */
    fun assertDisplayedById(viewId: Int): ViewInteraction {
        return assertDisplayed(withId(viewId))
    }

    /**
     * Assert view with text is displayed
     */
    fun assertDisplayedByText(text: String): ViewInteraction {
        return assertDisplayed(withText(text))
    }

    /**
     * Assert view is not displayed
     */
    fun assertNotDisplayed(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(not(isDisplayed())))
    }

    /**
     * Assert view is enabled
     */
    fun assertEnabled(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(isEnabled()))
    }

    /**
     * Assert view is not enabled
     */
    fun assertNotEnabled(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(not(isEnabled())))
    }

    /**
     * Assert view has text
     */
    fun assertHasText(viewMatcher: Matcher<View>, expectedText: String): ViewInteraction {
        return onView(viewMatcher).check(matches(withText(expectedText)))
    }

    /**
     * Assert view contains text
     */
    fun assertContainsText(viewMatcher: Matcher<View>, text: String): ViewInteraction {
        return onView(viewMatcher).check(matches(withText(containsString(text))))
    }

    /**
     * Assert view is clickable
     */
    fun assertClickable(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(isClickable()))
    }

    /**
     * Assert view is checked (for checkboxes, radio buttons)
     */
    fun assertChecked(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(isChecked()))
    }

    /**
     * Assert view is not checked
     */
    fun assertNotChecked(viewMatcher: Matcher<View>): ViewInteraction {
        return onView(viewMatcher).check(matches(not(isChecked())))
    }

    // MARK: - Screenshot Helpers

    /**
     * Capture screenshot
     */
    fun captureScreenshot(name: String = "screenshot"): File? {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName = "${name}_$timestamp.png"
            val screenshotDir = File(
                InstrumentationRegistry.getInstrumentation().targetContext.filesDir,
                "screenshots"
            )
            screenshotDir.mkdirs()

            val screenshotFile = File(screenshotDir, fileName)
            uiDevice.takeScreenshot(screenshotFile)
            screenshots.add(screenshotFile)

            log("Screenshot captured: $fileName", ZylixTestConfig.LogLevel.DEBUG)
            screenshotFile
        } catch (e: Exception) {
            log("Failed to capture screenshot: ${e.message}", ZylixTestConfig.LogLevel.ERROR)
            null
        }
    }

    /**
     * Get all captured screenshots
     */
    fun getScreenshots(): List<File> = screenshots.toList()

    // MARK: - Zylix Component Helpers

    /**
     * Verify Zylix component exists by tag pattern
     */
    fun verifyComponent(type: String, identifier: String? = null): Boolean {
        val tag = if (identifier != null) {
            "zylix-$type-$identifier"
        } else {
            "zylix-$type"
        }

        return try {
            onView(withTagValue(containsString(tag))).check(matches(isDisplayed()))
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get Zylix component by type and identifier
     */
    fun component(type: String, identifier: String): ViewInteraction {
        return viewWithTag("zylix-$type-$identifier")
    }

    /**
     * Verify button component
     */
    fun verifyButton(identifier: String, text: String? = null): Boolean {
        return try {
            val button = component("button", identifier)
            button.check(matches(isDisplayed()))
            text?.let { button.check(matches(withText(it))) }
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Verify text component
     */
    fun verifyText(identifier: String, contains: String): Boolean {
        return try {
            component("text", identifier)
                .check(matches(withText(containsString(contains))))
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Verify input component
     */
    fun verifyInput(identifier: String, value: String? = null): Boolean {
        return try {
            val input = component("input", identifier)
            input.check(matches(isDisplayed()))
            value?.let { input.check(matches(withText(it))) }
            true
        } catch (e: Exception) {
            false
        }
    }

    // MARK: - Logging

    private fun log(message: String, level: ZylixTestConfig.LogLevel) {
        if (level.level <= config.logLevel.level) {
            val prefix = when (level) {
                ZylixTestConfig.LogLevel.NONE -> return
                ZylixTestConfig.LogLevel.ERROR -> "[ERROR]"
                ZylixTestConfig.LogLevel.WARNING -> "[WARN]"
                ZylixTestConfig.LogLevel.INFO -> "[INFO]"
                ZylixTestConfig.LogLevel.DEBUG -> "[DEBUG]"
            }
            println("$prefix ZylixTest: $message")
        }
    }

    // MARK: - Activity Access

    /**
     * Execute action on activity
     */
    fun <R> onActivity(action: (T) -> R): R? {
        var result: R? = null
        scenario?.onActivity { activity ->
            result = action(activity)
        }
        return result
    }
}

/**
 * Custom ViewAction for waiting
 */
fun waitFor(delay: Long): ViewAction {
    return object : ViewAction {
        override fun getConstraints(): Matcher<View> = isRoot()

        override fun getDescription(): String = "Wait for $delay milliseconds"

        override fun perform(uiController: UiController, view: View?) {
            uiController.loopMainThreadForAtLeast(delay)
        }
    }
}
