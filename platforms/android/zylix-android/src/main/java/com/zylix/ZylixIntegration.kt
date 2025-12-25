package com.zylix

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.util.Size
import androidx.annotation.RequiresPermission
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.DefaultLifecycleObserver
import com.android.billingclient.api.*
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

// ============================================================================
// Integration Error Types
// ============================================================================

sealed class ZylixIntegrationError : Exception() {
    data object PermissionDenied : ZylixIntegrationError()
    data object DeviceNotAvailable : ZylixIntegrationError()
    data object ResourceNotFound : ZylixIntegrationError()
    data object ProductNotFound : ZylixIntegrationError()
    data object PurchaseFailed : ZylixIntegrationError()
    data object NotInitialized : ZylixIntegrationError()
    data class Unknown(override val message: String) : ZylixIntegrationError()
}

// ============================================================================
// Motion Frame Provider (#39)
// ============================================================================

/**
 * Resolution presets for motion capture.
 */
enum class MotionResolution(val width: Int, val height: Int) {
    VERY_LOW(80, 60),
    LOW(160, 120),
    MEDIUM(320, 240),
    HIGH(640, 480)
}

/**
 * Motion frame data.
 */
data class MotionFrame(
    val width: Int,
    val height: Int,
    val data: ByteArray,
    val timestamp: Long,
    val sequence: Long,
    var motionDetected: Boolean = false,
    var motionX: Float = 0.5f,
    var motionY: Float = 0.5f,
    var motionIntensity: Float = 0f
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as MotionFrame
        return sequence == other.sequence
    }

    override fun hashCode(): Int = sequence.hashCode()
}

/**
 * Motion frame configuration.
 */
data class MotionFrameConfig(
    var targetFPS: Int = 15,
    var resolution: MotionResolution = MotionResolution.LOW,
    var useFrontCamera: Boolean = true,
    var detectMotion: Boolean = false,
    var motionSensitivity: Float = 0.5f
)

/**
 * Motion Frame Provider for camera-based motion tracking.
 * Uses CameraX ImageAnalysis for efficient frame processing.
 */
class ZylixMotionFrameProvider(private val context: Context) {

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    private val _frameCount = MutableStateFlow(0L)
    val frameCount: StateFlow<Long> = _frameCount.asStateFlow()

    private val _lastFrame = MutableStateFlow<MotionFrame?>(null)
    val lastFrame: StateFlow<MotionFrame?> = _lastFrame.asStateFlow()

    private var config = MotionFrameConfig()
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var previousFrameData: ByteArray? = null
    private val executor = Executors.newSingleThreadExecutor()

    var onFrame: ((MotionFrame) -> Unit)? = null

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun configure(config: MotionFrameConfig) {
        this.config = config
    }

    /**
     * Start motion frame capture.
     */
    @SuppressLint("MissingPermission")
    fun start(lifecycleOwner: LifecycleOwner) {
        if (!hasPermission()) {
            throw ZylixIntegrationError.PermissionDenied
        }
        if (_isRunning.value) return

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            val cameraSelector = if (config.useFrontCamera) {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }

            imageAnalysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(config.resolution.width, config.resolution.height))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(executor) { imageProxy ->
                        processFrame(imageProxy)
                    }
                }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )
                _isRunning.value = true
                _frameCount.value = 0
                previousFrameData = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, ContextCompat.getMainExecutor(context))
    }

    /**
     * Stop motion frame capture.
     */
    fun stop() {
        cameraProvider?.unbindAll()
        imageAnalysis = null
        _isRunning.value = false
    }

    private fun processFrame(imageProxy: ImageProxy) {
        val buffer = imageProxy.planes[0].buffer
        val data = ByteArray(buffer.remaining())
        buffer.get(data)

        _frameCount.value++

        val frame = MotionFrame(
            width = imageProxy.width,
            height = imageProxy.height,
            data = data,
            timestamp = System.currentTimeMillis(),
            sequence = _frameCount.value
        )

        // Simple motion detection
        if (config.detectMotion && previousFrameData != null) {
            val prev = previousFrameData!!
            if (prev.size == data.size) {
                var diffSum = 0L
                var motionPixels = 0
                val threshold = ((1f - config.motionSensitivity) * 255).toInt()

                for (i in data.indices step 4) {
                    val diff = kotlin.math.abs(data[i].toInt() - prev[i].toInt())
                    if (diff > threshold) motionPixels++
                    diffSum += diff
                }

                val pixelCount = data.size / 4
                frame.motionIntensity = diffSum.toFloat() / (pixelCount * 255)
                frame.motionDetected = motionPixels > pixelCount / 100
            }
        }

        previousFrameData = data.copyOf()
        _lastFrame.value = frame
        onFrame?.invoke(frame)

        imageProxy.close()
    }

    companion object {
        @Volatile
        private var instance: ZylixMotionFrameProvider? = null

        fun getInstance(context: Context): ZylixMotionFrameProvider {
            return instance ?: synchronized(this) {
                instance ?: ZylixMotionFrameProvider(context.applicationContext).also { instance = it }
            }
        }

        fun isAvailable(context: Context): Boolean {
            return context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
        }
    }
}

// ============================================================================
// Audio Clip Player (#40)
// ============================================================================

/**
 * Audio clip for low-latency playback.
 */
data class AudioClip(
    val id: String,
    val resourceId: Int? = null,
    val path: String? = null,
    var volume: Float = 1f,
    var loop: Boolean = false
)

/**
 * Audio Clip Player for low-latency audio playback using SoundPool.
 */
class ZylixAudioClipPlayer(private val context: Context) {

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val loadedClips = mutableMapOf<String, AudioClip>()
    private val soundIds = mutableMapOf<String, Int>()
    private val streamIds = mutableMapOf<String, Int>()

    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(10)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    /**
     * Load an audio clip from resources.
     */
    fun load(clip: AudioClip): Boolean {
        val soundId = when {
            clip.resourceId != null -> soundPool.load(context, clip.resourceId, 1)
            clip.path != null -> soundPool.load(clip.path, 1)
            else -> return false
        }

        if (soundId != 0) {
            soundIds[clip.id] = soundId
            loadedClips[clip.id] = clip
            return true
        }
        return false
    }

    /**
     * Play a loaded clip.
     */
    fun play(clipId: String) {
        val soundId = soundIds[clipId] ?: return
        val clip = loadedClips[clipId] ?: return

        val streamId = soundPool.play(
            soundId,
            clip.volume,
            clip.volume,
            1,
            if (clip.loop) -1 else 0,
            1f
        )

        if (streamId != 0) {
            streamIds[clipId] = streamId
            _isPlaying.value = true
        }
    }

    /**
     * Stop a playing clip.
     */
    fun stop(clipId: String) {
        streamIds[clipId]?.let { streamId ->
            soundPool.stop(streamId)
            streamIds.remove(clipId)
        }
        updatePlayingState()
    }

    /**
     * Pause a playing clip.
     */
    fun pause(clipId: String) {
        streamIds[clipId]?.let { soundPool.pause(it) }
        updatePlayingState()
    }

    /**
     * Resume a paused clip.
     */
    fun resume(clipId: String) {
        streamIds[clipId]?.let { soundPool.resume(it) }
        _isPlaying.value = true
    }

    /**
     * Set volume for a clip.
     */
    fun setVolume(clipId: String, volume: Float) {
        val v = volume.coerceIn(0f, 1f)
        streamIds[clipId]?.let { soundPool.setVolume(it, v, v) }
        loadedClips[clipId]?.volume = v
    }

    /**
     * Unload a clip.
     */
    fun unload(clipId: String) {
        stop(clipId)
        soundIds[clipId]?.let { soundPool.unload(it) }
        soundIds.remove(clipId)
        loadedClips.remove(clipId)
    }

    /**
     * Unload all clips.
     */
    fun unloadAll() {
        soundIds.keys.toList().forEach { unload(it) }
    }

    /**
     * Release resources.
     */
    fun release() {
        unloadAll()
        soundPool.release()
    }

    private fun updatePlayingState() {
        _isPlaying.value = streamIds.isNotEmpty()
    }

    companion object {
        @Volatile
        private var instance: ZylixAudioClipPlayer? = null

        fun getInstance(context: Context): ZylixAudioClipPlayer {
            return instance ?: synchronized(this) {
                instance ?: ZylixAudioClipPlayer(context.applicationContext).also { instance = it }
            }
        }

        fun isAvailable(): Boolean = true
    }
}

// ============================================================================
// In-App Purchase Store (#41)
// ============================================================================

/**
 * IAP Product.
 */
data class IAPProduct(
    val id: String,
    val displayName: String,
    val description: String,
    val price: String,
    val priceAmountMicros: Long,
    val isSubscription: Boolean
)

/**
 * Purchase result.
 */
sealed class IAPPurchaseResult {
    data class Success(val orderId: String?) : IAPPurchaseResult()
    data object Pending : IAPPurchaseResult()
    data object Cancelled : IAPPurchaseResult()
    data class Failed(val error: Exception) : IAPPurchaseResult()
}

/**
 * In-App Purchase Store using Google Play Billing.
 */
class ZylixIAPStore(private val context: Context) : PurchasesUpdatedListener {

    private val _products = MutableStateFlow<List<IAPProduct>>(emptyList())
    val products: StateFlow<List<IAPProduct>> = _products.asStateFlow()

    private val _purchasedProductIds = MutableStateFlow<Set<String>>(emptySet())
    val purchasedProductIds: StateFlow<Set<String>> = _purchasedProductIds.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private var billingClient: BillingClient? = null
    private var productIds: Set<String> = emptySet()
    private var subscriptionIds: Set<String> = emptySet()
    private var pendingPurchaseCallback: ((IAPPurchaseResult) -> Unit)? = null

    /**
     * Initialize billing client.
     */
    fun initialize() {
        billingClient = BillingClient.newBuilder(context)
            .setListener(this)
            .enablePendingPurchases()
            .build()

        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryPurchases()
                }
            }

            override fun onBillingServiceDisconnected() {
                // Reconnect logic could go here
            }
        })
    }

    /**
     * Configure product IDs.
     */
    fun configure(productIds: Set<String>, subscriptionIds: Set<String> = emptySet()) {
        this.productIds = productIds
        this.subscriptionIds = subscriptionIds
    }

    /**
     * Load products from Play Store.
     */
    suspend fun loadProducts() {
        _isLoading.value = true

        val allProducts = mutableListOf<IAPProduct>()

        // Query in-app products
        if (productIds.isNotEmpty()) {
            val productList = productIds.map {
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(it)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build()
            }

            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(productList)
                .build()

            billingClient?.queryProductDetailsAsync(params) { result, details ->
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    allProducts.addAll(details.map { detail ->
                        IAPProduct(
                            id = detail.productId,
                            displayName = detail.name,
                            description = detail.description,
                            price = detail.oneTimePurchaseOfferDetails?.formattedPrice ?: "",
                            priceAmountMicros = detail.oneTimePurchaseOfferDetails?.priceAmountMicros ?: 0,
                            isSubscription = false
                        )
                    })
                }
            }
        }

        // Query subscriptions
        if (subscriptionIds.isNotEmpty()) {
            val subList = subscriptionIds.map {
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(it)
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build()
            }

            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(subList)
                .build()

            billingClient?.queryProductDetailsAsync(params) { result, details ->
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    allProducts.addAll(details.map { detail ->
                        val offer = detail.subscriptionOfferDetails?.firstOrNull()
                        val phase = offer?.pricingPhases?.pricingPhaseList?.firstOrNull()
                        IAPProduct(
                            id = detail.productId,
                            displayName = detail.name,
                            description = detail.description,
                            price = phase?.formattedPrice ?: "",
                            priceAmountMicros = phase?.priceAmountMicros ?: 0,
                            isSubscription = true
                        )
                    })
                }
            }
        }

        _products.value = allProducts
        _isLoading.value = false
    }

    /**
     * Purchase a product.
     */
    suspend fun purchase(
        activity: android.app.Activity,
        productId: String
    ): IAPPurchaseResult = suspendCancellableCoroutine { continuation ->
        val productList = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(productId)
                .setProductType(
                    if (subscriptionIds.contains(productId)) BillingClient.ProductType.SUBS
                    else BillingClient.ProductType.INAPP
                )
                .build()
        )

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        billingClient?.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK || details.isEmpty()) {
                continuation.resume(IAPPurchaseResult.Failed(ZylixIntegrationError.ProductNotFound))
                return@queryProductDetailsAsync
            }

            val detail = details.first()
            val flowParams = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(detail)
                            .build()
                    )
                )
                .build()

            pendingPurchaseCallback = { result ->
                continuation.resume(result)
            }

            billingClient?.launchBillingFlow(activity, flowParams)
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        val purchaseResult = when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { purchase ->
                    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        acknowledgePurchase(purchase)
                    }
                }
                queryPurchases()
                IAPPurchaseResult.Success(purchases?.firstOrNull()?.orderId)
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> IAPPurchaseResult.Cancelled
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                queryPurchases()
                IAPPurchaseResult.Success(null)
            }
            else -> IAPPurchaseResult.Failed(ZylixIntegrationError.PurchaseFailed)
        }

        pendingPurchaseCallback?.invoke(purchaseResult)
        pendingPurchaseCallback = null
    }

    private fun acknowledgePurchase(purchase: Purchase) {
        if (!purchase.isAcknowledged) {
            val params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient?.acknowledgePurchase(params) { }
        }
    }

    private fun queryPurchases() {
        val purchased = mutableSetOf<String>()

        billingClient?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        ) { _, purchases ->
            purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                .forEach { purchased.addAll(it.products) }
        }

        billingClient?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        ) { _, purchases ->
            purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                .forEach { purchased.addAll(it.products) }
        }

        _purchasedProductIds.value = purchased
    }

    /**
     * Check if product is purchased.
     */
    fun isPurchased(productId: String): Boolean {
        return _purchasedProductIds.value.contains(productId)
    }

    /**
     * Release resources.
     */
    fun release() {
        billingClient?.endConnection()
        billingClient = null
    }

    companion object {
        @Volatile
        private var instance: ZylixIAPStore? = null

        fun getInstance(context: Context): ZylixIAPStore {
            return instance ?: synchronized(this) {
                instance ?: ZylixIAPStore(context.applicationContext).also { instance = it }
            }
        }

        fun isAvailable(): Boolean = true
    }
}

// ============================================================================
// Ads Manager (#42)
// ============================================================================

/**
 * Ad reward.
 */
data class ZylixAdReward(
    val type: String,
    val amount: Int
)

/**
 * Consent status for GDPR.
 */
enum class ZylixConsentStatus {
    UNKNOWN,
    REQUIRED,
    NOT_REQUIRED,
    OBTAINED
}

/**
 * Ads Manager (AdMob integration placeholder).
 * Note: Actual AdMob integration requires Google Mobile Ads SDK.
 */
class ZylixAdsManager(private val context: Context) {

    private val _isBannerVisible = MutableStateFlow(false)
    val isBannerVisible: StateFlow<Boolean> = _isBannerVisible.asStateFlow()

    private val _isInterstitialReady = MutableStateFlow(false)
    val isInterstitialReady: StateFlow<Boolean> = _isInterstitialReady.asStateFlow()

    private val _isRewardedReady = MutableStateFlow(false)
    val isRewardedReady: StateFlow<Boolean> = _isRewardedReady.asStateFlow()

    private val _consentStatus = MutableStateFlow(ZylixConsentStatus.UNKNOWN)
    val consentStatus: StateFlow<ZylixConsentStatus> = _consentStatus.asStateFlow()

    private var bannerAdUnitId: String? = null
    private var interstitialAdUnitId: String? = null
    private var rewardedAdUnitId: String? = null

    var onRewardEarned: ((ZylixAdReward) -> Unit)? = null

    /**
     * Initialize with app ID.
     */
    fun initialize(appId: String) {
        // MobileAds.initialize(context)
        println("[ZylixAds] Initialized with appId: $appId")
    }

    /**
     * Configure ad unit IDs.
     */
    fun configure(
        bannerAdUnitId: String? = null,
        interstitialAdUnitId: String? = null,
        rewardedAdUnitId: String? = null
    ) {
        this.bannerAdUnitId = bannerAdUnitId
        this.interstitialAdUnitId = interstitialAdUnitId
        this.rewardedAdUnitId = rewardedAdUnitId
    }

    /**
     * Load banner ad.
     */
    fun loadBanner() {
        if (bannerAdUnitId == null) return
        println("[ZylixAds] Loading banner ad")
    }

    /**
     * Show banner ad.
     */
    fun showBanner() {
        _isBannerVisible.value = true
    }

    /**
     * Hide banner ad.
     */
    fun hideBanner() {
        _isBannerVisible.value = false
    }

    /**
     * Load interstitial ad.
     */
    fun loadInterstitial() {
        if (interstitialAdUnitId == null) return
        println("[ZylixAds] Loading interstitial ad")
        _isInterstitialReady.value = true
    }

    /**
     * Show interstitial ad.
     */
    fun showInterstitial(activity: android.app.Activity) {
        if (!_isInterstitialReady.value) return
        println("[ZylixAds] Showing interstitial ad")
        _isInterstitialReady.value = false
    }

    /**
     * Load rewarded ad.
     */
    fun loadRewarded() {
        if (rewardedAdUnitId == null) return
        println("[ZylixAds] Loading rewarded ad")
        _isRewardedReady.value = true
    }

    /**
     * Show rewarded ad.
     */
    fun showRewarded(activity: android.app.Activity) {
        if (!_isRewardedReady.value) return
        println("[ZylixAds] Showing rewarded ad")
        _isRewardedReady.value = false

        // Simulate reward
        onRewardEarned?.invoke(ZylixAdReward("coins", 100))
    }

    /**
     * Request consent (GDPR).
     */
    fun requestConsent(activity: android.app.Activity) {
        // UMP SDK implementation would go here
        _consentStatus.value = ZylixConsentStatus.OBTAINED
    }

    companion object {
        @Volatile
        private var instance: ZylixAdsManager? = null

        fun getInstance(context: Context): ZylixAdsManager {
            return instance ?: synchronized(this) {
                instance ?: ZylixAdsManager(context.applicationContext).also { instance = it }
            }
        }

        fun isAvailable(): Boolean = true
    }
}

// ============================================================================
// Key-Value Store (#43)
// ============================================================================

/**
 * Persistent Key-Value Store using SharedPreferences.
 */
class ZylixKeyValueStore(context: Context, name: String = "zylix_prefs") {

    private val prefs: SharedPreferences = context.getSharedPreferences(name, Context.MODE_PRIVATE)

    private val _count = MutableStateFlow(prefs.all.size)
    val count: StateFlow<Int> = _count.asStateFlow()

    // Getters

    fun getBool(key: String, default: Boolean = false): Boolean = prefs.getBoolean(key, default)
    fun getInt(key: String, default: Int = 0): Int = prefs.getInt(key, default)
    fun getLong(key: String, default: Long = 0L): Long = prefs.getLong(key, default)
    fun getFloat(key: String, default: Float = 0f): Float = prefs.getFloat(key, default)
    fun getString(key: String, default: String = ""): String = prefs.getString(key, default) ?: default

    fun getStringSet(key: String, default: Set<String> = emptySet()): Set<String> {
        return prefs.getStringSet(key, default) ?: default
    }

    // Setters

    fun putBool(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
        updateCount()
    }

    fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
        updateCount()
    }

    fun putLong(key: String, value: Long) {
        prefs.edit().putLong(key, value).apply()
        updateCount()
    }

    fun putFloat(key: String, value: Float) {
        prefs.edit().putFloat(key, value).apply()
        updateCount()
    }

    fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
        updateCount()
    }

    fun putStringSet(key: String, value: Set<String>) {
        prefs.edit().putStringSet(key, value).apply()
        updateCount()
    }

    // Management

    fun contains(key: String): Boolean = prefs.contains(key)

    fun remove(key: String) {
        prefs.edit().remove(key).apply()
        updateCount()
    }

    fun clear() {
        prefs.edit().clear().apply()
        updateCount()
    }

    fun keys(): Set<String> = prefs.all.keys

    private fun updateCount() {
        _count.value = prefs.all.size
    }

    companion object {
        @Volatile
        private var instance: ZylixKeyValueStore? = null

        fun getInstance(context: Context): ZylixKeyValueStore {
            return instance ?: synchronized(this) {
                instance ?: ZylixKeyValueStore(context.applicationContext).also { instance = it }
            }
        }
    }
}

// ============================================================================
// App Lifecycle (#44)
// ============================================================================

/**
 * App state.
 */
enum class ZylixAppState {
    NOT_RUNNING,
    LAUNCHING,
    FOREGROUND,
    BACKGROUND,
    SUSPENDED,
    TERMINATING
}

/**
 * Memory pressure level.
 */
enum class ZylixMemoryPressure {
    NORMAL,
    WARNING,
    CRITICAL
}

/**
 * App Lifecycle Manager using ProcessLifecycleOwner.
 */
class ZylixAppLifecycle private constructor() : DefaultLifecycleObserver {

    private val _state = MutableStateFlow(ZylixAppState.NOT_RUNNING)
    val state: StateFlow<ZylixAppState> = _state.asStateFlow()

    var onForeground: (() -> Unit)? = null
    var onBackground: (() -> Unit)? = null
    var onTerminate: (() -> Unit)? = null
    var onMemoryWarning: ((ZylixMemoryPressure) -> Unit)? = null

    val isInForeground: Boolean get() = _state.value == ZylixAppState.FOREGROUND
    val isInBackground: Boolean get() = _state.value == ZylixAppState.BACKGROUND

    /**
     * Initialize lifecycle observer.
     */
    fun initialize() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) {
        _state.value = ZylixAppState.FOREGROUND
        onForeground?.invoke()
    }

    override fun onStop(owner: LifecycleOwner) {
        _state.value = ZylixAppState.BACKGROUND
        onBackground?.invoke()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        _state.value = ZylixAppState.TERMINATING
        onTerminate?.invoke()
    }

    /**
     * Handle memory trim (call from Application.onTrimMemory).
     */
    fun handleMemoryTrim(level: Int) {
        val pressure = when {
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ->
                ZylixMemoryPressure.CRITICAL
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ->
                ZylixMemoryPressure.WARNING
            else -> ZylixMemoryPressure.NORMAL
        }
        if (pressure != ZylixMemoryPressure.NORMAL) {
            onMemoryWarning?.invoke(pressure)
        }
    }

    companion object {
        val instance: ZylixAppLifecycle by lazy { ZylixAppLifecycle() }
    }
}

// ============================================================================
// Unified Integration Manager
// ============================================================================

/**
 * Unified Integration Manager for all services.
 */
class ZylixIntegration private constructor(context: Context) {

    val motion: ZylixMotionFrameProvider = ZylixMotionFrameProvider.getInstance(context)
    val audioClip: ZylixAudioClipPlayer = ZylixAudioClipPlayer.getInstance(context)
    val store: ZylixIAPStore = ZylixIAPStore.getInstance(context)
    val ads: ZylixAdsManager = ZylixAdsManager.getInstance(context)
    val keyValue: ZylixKeyValueStore = ZylixKeyValueStore.getInstance(context)
    val lifecycle: ZylixAppLifecycle = ZylixAppLifecycle.instance

    companion object {
        @Volatile
        private var instance: ZylixIntegration? = null

        /**
         * Initialize the integration manager.
         */
        fun initialize(context: Context): ZylixIntegration {
            return instance ?: synchronized(this) {
                instance ?: ZylixIntegration(context.applicationContext).also {
                    instance = it
                    it.lifecycle.initialize()
                }
            }
        }

        /**
         * Get the shared instance.
         */
        fun getInstance(): ZylixIntegration {
            return instance ?: throw ZylixIntegrationError.NotInitialized
        }
    }

    /**
     * Release all resources.
     */
    fun release() {
        motion.stop()
        audioClip.release()
        store.release()
    }
}
