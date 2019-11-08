#https://quay.io/repository/bitriseio/bitrise-base?tab=tags
#Image being leverage as the base image to build Android apps against
FROM quay.io/bitriseio/bitrise-base:latest

MAINTAINER Tanck <softtanck@163.com>

ENV ANDROID_HOME /opt/android-sdk-linux

# ------------------------------------------------------
# --- Install required tools

RUN apt-get update -qq

# Base (non android specific) tools
# -> should be added to bitriseio/docker-bitrise-base

# Dependencies to execute Android builds
RUN dpkg --add-architecture i386
RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk libc6:i386 libstdc++6:i386 libgcc1:i386 libncurses5:i386 libz1:i386

# ------------------------------------------------------
# --- Download Android SDK tools into $ANDROID_HOME

RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk-tools.zip \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME} \
    && rm android-sdk-tools.zip

ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools

# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
RUN sdkmanager --list

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

# Platform tools
RUN sdkmanager "emulator" "tools" "platform-tools"

# Setup NDK
ENV ANDROID_NDK_HOME ${ANDROID_HOME}/ndk-bundle
RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip -O android-ndk-r15c.zip \
    && unzip -q android-ndk-r15c.zip -d ${ANDROID_NDK_HOME} \
    && mv ${ANDROID_NDK_HOME}/android-ndk-r15c/* ${ANDROID_NDK_HOME} \
    && rm android-ndk-r15c.zip

# SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.

# Please keep all sections in descending order!
RUN yes | sdkmanager \
    "platforms;android-28" \
    "build-tools;28.0.3" \
    "platforms;android-27" \
    "build-tools;27.0.3" \
    "platforms;android-26" \
    "build-tools;26.0.2" \
    "system-images;android-25;google_apis;armeabi-v7a" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.2" \
    "add-ons;addon-google_apis-google-24"

# ------------------------------------------------------
# --- Install Gradle from PPA

# Gradle PPA
RUN apt-get update \
 && apt-get -y install gradle \
 && gradle -v \

# ------------------------------------------------------
# --- Install Maven 3 from PPA

RUN apt-get purge maven maven2 \
 && apt-get update \
 && apt-get -y install maven \
 && mvn --version

# ------------------------------------------------------
# --- Install additional packages

# Required for Android ARM Emulator
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libqt5widgets5
ENV QT_QPA_PLATFORM offscreen
ENV LD_LIBRARY_PATH ${ANDROID_HOME}/tools/lib64:${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/qt/lib

# ------------------------------------------------------
# --- Cleanup and rev num

# Cleaning
RUN apt-get clean

# Set gradlew permission
#RUN chmod +x ./gradlew

ENV BITRISE_DOCKER_REV_NUMBER_ANDROID v2017_12_29_1
CMD bitrise -version
