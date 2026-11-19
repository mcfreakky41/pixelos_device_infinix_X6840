#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),X6840)
include $(call all-subdir-makefiles,$(LOCAL_PATH))

# ---- Prebuilt vendor APK overlays ----
# Installed as ETC prebuilts to preserve exact paths; included via PRODUCT_PACKAGES.
include $(CLEAR_VARS)
LOCAL_MODULE := NetworkStackGoogleGoResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := NetworkStackGoogleGoResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/app/NetworkStackGoogleGoResOverlay/NetworkStackGoogleGoResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/app/NetworkStackGoogleGoResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := NetworkStackGoogleResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := NetworkStackGoogleResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/app/NetworkStackGoogleResOverlay/NetworkStackGoogleResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/app/NetworkStackGoogleResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := NetworkStackResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := NetworkStackResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/app/NetworkStackResOverlay/NetworkStackResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/app/NetworkStackResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := TetheringGoogleResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := TetheringGoogleResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/app/TetheringGoogleResOverlay/TetheringGoogleResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/app/TetheringGoogleResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := TetheringResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := TetheringResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/app/TetheringResOverlay/TetheringResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/app/TetheringResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := CellbroadcastUIResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := CellbroadcastUIResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/CellbroadcastUIResOverlay/CellbroadcastUIResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/CellbroadcastUIResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := ConnectivityResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := ConnectivityResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/ConnectivityResOverlay/ConnectivityResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/ConnectivityResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := FrameworkResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := FrameworkResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/FrameworkResOverlay/FrameworkResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/FrameworkResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := FrameworkResOverlayExt
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := FrameworkResOverlayExt.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/FrameworkResOverlayExt/FrameworkResOverlayExt.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/FrameworkResOverlayExt
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := MtkSettingsResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := MtkSettingsResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/MtkSettingsResOverlay/MtkSettingsResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/MtkSettingsResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := MtkTelephonyServiceResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := MtkTelephonyServiceResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/MtkTelephonyServiceResOverlay/MtkTelephonyServiceResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/MtkTelephonyServiceResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := SettingsProviderResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := SettingsProviderResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/SettingsProviderResOverlay/SettingsProviderResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/SettingsProviderResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := SystemUIResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := SystemUIResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/SystemUIResOverlay/SystemUIResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/SystemUIResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := WifiResMainlineOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := WifiResMainlineOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/WifiResMainlineOverlay/WifiResMainlineOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/WifiResMainlineOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
include $(CLEAR_VARS)
LOCAL_MODULE := WifiResOverlay
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := WifiResOverlay.apk
LOCAL_SRC_FILES := proprietary/vendor/overlay/WifiResOverlay/WifiResOverlay.apk
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/WifiResOverlay
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_PREBUILT)
endif
