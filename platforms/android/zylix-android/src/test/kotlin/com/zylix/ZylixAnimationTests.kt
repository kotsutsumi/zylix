package com.zylix

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for ZylixAnimation module.
 */
class ZylixAnimationTests {

    // MARK: - Easing Function Tests

    @Test
    fun `test linear easing`() {
        assertEquals(0.0f, ZylixEasing.linear(0.0f), 0.001f)
        assertEquals(0.5f, ZylixEasing.linear(0.5f), 0.001f)
        assertEquals(1.0f, ZylixEasing.linear(1.0f), 0.001f)
    }

    @Test
    fun `test easeInQuad`() {
        assertEquals(0.0f, ZylixEasing.easeInQuad(0.0f), 0.001f)
        assertEquals(0.25f, ZylixEasing.easeInQuad(0.5f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInQuad(1.0f), 0.001f)
    }

    @Test
    fun `test easeOutQuad`() {
        assertEquals(0.0f, ZylixEasing.easeOutQuad(0.0f), 0.001f)
        assertTrue(ZylixEasing.easeOutQuad(0.5f) > 0.5f)
        assertEquals(1.0f, ZylixEasing.easeOutQuad(1.0f), 0.001f)
    }

    @Test
    fun `test easeInOutQuad`() {
        assertEquals(0.0f, ZylixEasing.easeInOutQuad(0.0f), 0.001f)
        assertEquals(0.5f, ZylixEasing.easeInOutQuad(0.5f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInOutQuad(1.0f), 0.001f)
    }

    @Test
    fun `test easeInCubic`() {
        assertEquals(0.0f, ZylixEasing.easeInCubic(0.0f), 0.001f)
        assertEquals(0.125f, ZylixEasing.easeInCubic(0.5f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInCubic(1.0f), 0.001f)
    }

    @Test
    fun `test easeOutCubic`() {
        assertEquals(0.0f, ZylixEasing.easeOutCubic(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeOutCubic(1.0f), 0.001f)
    }

    @Test
    fun `test easeInSine`() {
        assertEquals(0.0f, ZylixEasing.easeInSine(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInSine(1.0f), 0.001f)
    }

    @Test
    fun `test easeOutSine`() {
        assertEquals(0.0f, ZylixEasing.easeOutSine(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeOutSine(1.0f), 0.001f)
    }

    @Test
    fun `test easeInExpo`() {
        assertEquals(0.0f, ZylixEasing.easeInExpo(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInExpo(1.0f), 0.001f)
    }

    @Test
    fun `test easeOutExpo`() {
        assertEquals(0.0f, ZylixEasing.easeOutExpo(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeOutExpo(1.0f), 0.001f)
    }

    @Test
    fun `test easeOutBounce boundary values`() {
        assertEquals(0.0f, ZylixEasing.easeOutBounce(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeOutBounce(1.0f), 0.001f)
    }

    @Test
    fun `test easeInBounce`() {
        assertEquals(0.0f, ZylixEasing.easeInBounce(0.0f), 0.001f)
        assertEquals(1.0f, ZylixEasing.easeInBounce(1.0f), 0.001f)
    }

    @Test
    fun `test spring easing`() {
        val result = ZylixEasing.spring(1.0f)
        assertTrue(result > 0f)
    }

    @Test
    fun `test spring with custom parameters`() {
        val result = ZylixEasing.spring(0.5f, stiffness = 200f, damping = 5f, mass = 1f)
        assertTrue(result >= 0f)
    }

    // MARK: - SpringConfig Tests

    @Test
    fun `test default SpringConfig`() {
        val config = SpringConfig()

        assertEquals(100f, config.stiffness)
        assertEquals(10f, config.damping)
        assertEquals(1f, config.mass)
    }

    @Test
    fun `test preset SpringConfigs`() {
        val gentle = SpringConfig.gentle
        assertEquals(50f, gentle.stiffness)
        assertEquals(8f, gentle.damping)

        val bouncy = SpringConfig.bouncy
        assertEquals(200f, bouncy.stiffness)
        assertEquals(5f, bouncy.damping)

        val stiff = SpringConfig.stiff
        assertEquals(300f, stiff.stiffness)
        assertEquals(20f, stiff.damping)
    }

    // MARK: - Keyframe Tests

    @Test
    fun `test Keyframe creation`() {
        val keyframe = Keyframe(0.5f, 100f)

        assertEquals(0.5f, keyframe.time)
        assertEquals(100f, keyframe.value)
    }

    @Test
    fun `test KeyframeAnimation interpolation`() {
        val animation = KeyframeAnimation(listOf(
            Keyframe(0f, 0f),
            Keyframe(0.5f, 50f),
            Keyframe(1f, 100f)
        ))

        assertEquals(0f, animation.getValue(0f), 0.01f)
        assertEquals(100f, animation.getValue(1f), 0.01f)
    }

    @Test
    fun `test KeyframeAnimation empty list`() {
        val animation = KeyframeAnimation(emptyList())
        assertEquals(0f, animation.getValue(0.5f), 0.01f)
    }

    @Test
    fun `test KeyframeAnimation single keyframe`() {
        val animation = KeyframeAnimation(listOf(
            Keyframe(0.5f, 42f)
        ))
        assertEquals(42f, animation.getValue(0.5f), 0.01f)
    }

    // MARK: - AnimationState Tests

    @Test
    fun `test AnimationState values`() {
        assertEquals("IDLE", AnimationState.IDLE.name)
        assertEquals("RUNNING", AnimationState.RUNNING.name)
        assertEquals("PAUSED", AnimationState.PAUSED.name)
        assertEquals("FINISHED", AnimationState.FINISHED.name)
    }

    // MARK: - Repeat Mode Tests

    @Test
    fun `test RepeatMode values`() {
        assertEquals("NONE", RepeatMode.NONE.name)
        assertEquals("LOOP", RepeatMode.LOOP.name)
        assertEquals("PING_PONG", RepeatMode.PING_PONG.name)
    }

    // MARK: - AnimationConfig Tests

    @Test
    fun `test AnimationConfig defaults`() {
        val config = AnimationConfig()

        assertEquals(300L, config.duration)
        assertEquals(0L, config.delay)
        assertEquals(RepeatMode.NONE, config.repeatMode)
        assertEquals(0, config.repeatCount)
    }

    @Test
    fun `test AnimationConfig custom values`() {
        val config = AnimationConfig(
            duration = 500L,
            delay = 100L,
            repeatMode = RepeatMode.LOOP,
            repeatCount = 3
        )

        assertEquals(500L, config.duration)
        assertEquals(100L, config.delay)
        assertEquals(RepeatMode.LOOP, config.repeatMode)
        assertEquals(3, config.repeatCount)
    }
}
