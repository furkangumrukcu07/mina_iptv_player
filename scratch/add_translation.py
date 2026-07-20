import re

translations = {
    'tr_TR': "'3 Cihaz Daha Ekle'",
    'en_US': "'Add 3 More Devices'",
    'de_DE': "'3 Weitere Geräte Hinzufügen'",
    'es_ES': "'Añadir 3 Dispositivos Más'",
    'fr_FR': "'Ajouter 3 Appareils Supplémentaires'",
    'nl_NL': "'Voeg Nog 3 Apparaten Toe'",
    'ar_SA': "'إضافة 3 أجهزة أخرى'",
    'pt_PT': "'Adicionar Mais 3 Dispositivos'",
    'ru_RU': "'Добавить еще 3 устройства'",
    'it_IT': "'Aggiungi Altri 3 Dispositivi'"
}

with open('lib/core/i18n/app_translations.dart', 'r') as f:
    content = f.read()

# find all sections like 'tr_TR': { ... }
# we will just replace `'paywall.button.buy': '...',` with `'paywall.button.buy': '...', \n  'paywall.button.buy3devices': 'Add 3 More Devices',`

lines = content.split('\n')
out_lines = []

current_lang = 'en_US' # default fallback
lang_regex = re.compile(r"^\s*'([a-z]{2}_[A-Z]{2})':\s*\{")

for line in lines:
    m = lang_regex.search(line)
    if m:
        current_lang = m.group(1)
        
    out_lines.append(line)
    
    if "'paywall.button.buy':" in line:
        val = translations.get(current_lang, "'Add 3 More Devices'")
        out_lines.append(f"  'paywall.button.buy3devices': {val},")

with open('lib/core/i18n/app_translations.dart', 'w') as f:
    f.write('\n'.join(out_lines))

print("Translations added.")
