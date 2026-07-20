package com.mina.iptv.mina_iptv_player

import android.app.Application
import io.flutter.FlutterInjector

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Activity ve arka plan servisleri (Firebase vb.) çakışmadan önce 
        // Flutter yükleyicisini ana thread'de garanti altına alıyoruz.
        // Bu işlem FlutterApplicationInfo NullPointerException hatasını (Fatal Crash) engeller.
        FlutterInjector.instance().flutterLoader().startInitialization(this)
    }
}
