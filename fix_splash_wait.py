with open('lib/core/services/chat_service.dart', 'r') as f:
    content = f.read()

target = """      // Sıçrama (Splash) ekranı veya henüz hazır değilse bekle.
      // Bu sayede splash ekranı kapanırken pop-up'ın da kapanmasını engelliyoruz.
      while (Get.currentRoute == '/' || Get.currentRoute.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }"""

replacement = """      // Sıçrama (Splash) ekranı veya henüz hazır değilse bekle.
      // Bu sayede splash ekranı kapanırken pop-up'ın da kapanmasını engelliyoruz.
      while (Get.currentRoute == '/' || Get.currentRoute.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Navigasyon geçişinin (animasyonunun) tamamen bitmesi için ekstra bekleme süresi:
      // Aksi halde Get.offAll işlemi sırasında dialog da kaybolabiliyor.
      await Future.delayed(const Duration(seconds: 2));"""

content = content.replace(target, replacement)

with open('lib/core/services/chat_service.dart', 'w') as f:
    f.write(content)
