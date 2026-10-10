import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  final AppLanguageService _service = AppLanguageService.instance;

  static const Map<AppLanguage, Map<String, String>> _labels = {
    AppLanguage.english: {
      'title': 'Language Settings',
      'description':
          'Choose your preferred language for supported app screens.',
      'available': 'Available languages',
      'count': '{count} languages',
      'saving': 'Saving language preference...',
      'note': 'Translated labels appear where translations are available. AI responses depend on backend language support.',
      'selected': 'Selected: {language}',
      'save_failed': 'Could not save language preference.',
    },
    AppLanguage.hindi: {
      'title': 'भाषा सेटिंग्स',
      'description': 'ऐप की समर्थित स्क्रीन के लिए अपनी पसंदीदा भाषा चुनें।',
      'available': 'उपलब्ध भाषाएँ',
      'count': '{count} भाषाएँ',
      'saving': 'भाषा की पसंद सहेजी जा रही है...',
      'note': 'जहाँ अनुवाद उपलब्ध हैं, वहाँ अनुवादित लेबल दिखाई देंगे। AI उत्तरों के लिए बैकएंड भाषा समर्थन आवश्यक है।',
      'selected': 'चुनी गई भाषा: {language}',
      'save_failed': 'भाषा की पसंद सहेजी नहीं जा सकी।',
    },
    AppLanguage.gujarati: {
      'title': 'ભાષા સેટિંગ્સ',
      'description': 'એપની સપોર્ટેડ સ્ક્રીન માટે તમારી પસંદગીની ભાષા પસંદ કરો.',
      'available': 'ઉપલબ્ધ ભાષાઓ',
      'count': '{count} ભાષાઓ',
      'saving': 'ભાષાની પસંદગી સાચવાઈ રહી છે...',
      'note': 'જ્યાં અનુવાદ ઉપલબ્ધ છે ત્યાં અનુવાદિત લેબલ દેખાશે. AI જવાબો માટે બેકએન્ડનો ભાષા સપોર્ટ જરૂરી છે.',
      'selected': 'પસંદ કરેલી ભાષા: {language}',
      'save_failed': 'ભાષાની પસંદગી સાચવી શકાઈ નથી.',
    },
    AppLanguage.marathi: {
      'title': 'भाषा सेटिंग्ज',
      'description': 'अॅपच्या समर्थित स्क्रीनसाठी तुमची आवडती भाषा निवडा.',
      'available': 'उपलब्ध भाषा',
      'count': '{count} भाषा',
      'saving': 'भाषेची निवड जतन होत आहे...',
      'note': 'अनुवाद उपलब्ध असलेल्या ठिकाणी अनुवादित मजकूर दिसेल. AI उत्तरांसाठी बॅकएंडचा भाषा सपोर्ट आवश्यक आहे.',
      'selected': 'निवडलेली भाषा: {language}',
      'save_failed': 'भाषेची निवड जतन करता आली नाही.',
    },
    AppLanguage.bengali: {
      'title': 'ভাষা সেটিংস',
      'description':
          'সমর্থিত অ্যাপ স্ক্রিনের জন্য আপনার পছন্দের ভাষা বেছে নিন।',
      'available': 'উপলভ্য ভাষা',
      'count': '{count}টি ভাষা',
      'saving': 'ভাষার পছন্দ সংরক্ষণ করা হচ্ছে...',
      'note': 'অনুবাদ উপলভ্য থাকলে সেই ভাষায় লেখা দেখা যাবে। AI উত্তরের জন্য ব্যাকএন্ডে ভাষার সমর্থন প্রয়োজন।',
      'selected': 'নির্বাচিত ভাষা: {language}',
      'save_failed': 'ভাষার পছন্দ সংরক্ষণ করা যায়নি।',
    },
    AppLanguage.tamil: {
      'title': 'மொழி அமைப்புகள்',
      'description': 'ஆதரிக்கப்படும் செயலித் திரைகளுக்கு விருப்பமான மொழியைத் தேர்ந்தெடுக்கவும்.',
      'available': 'கிடைக்கும் மொழிகள்',
      'count': '{count} மொழிகள்',
      'saving': 'மொழி விருப்பம் சேமிக்கப்படுகிறது...',
      'note': 'மொழிபெயர்ப்பு உள்ள இடங்களில் மொழிபெயர்க்கப்பட்ட உரைகள் தோன்றும். AI பதில்களுக்கு பின்தள மொழி ஆதரவு தேவை.',
      'selected': 'தேர்ந்தெடுக்கப்பட்ட மொழி: {language}',
      'save_failed': 'மொழி விருப்பத்தைச் சேமிக்க முடியவில்லை.',
    },
    AppLanguage.telugu: {
      'title': 'భాషా సెట్టింగ్‌లు',
      'description':
          'మద్దతు ఉన్న యాప్ స్క్రీన్‌ల కోసం మీకు నచ్చిన భాషను ఎంచుకోండి.',
      'available': 'అందుబాటులో ఉన్న భాషలు',
      'count': '{count} భాషలు',
      'saving': 'భాషా ఎంపికను సేవ్ చేస్తున్నాం...',
      'note': 'అనువాదాలు అందుబాటులో ఉన్న చోట అనువదించిన లేబుళ్లు కనిపిస్తాయి. AI సమాధానాలకు బ్యాకెండ్ భాషా మద్దతు అవసరం.',
      'selected': 'ఎంచుకున్న భాష: {language}',
      'save_failed': 'భాషా ఎంపికను సేవ్ చేయలేకపోయాం.',
    },
    AppLanguage.kannada: {
      'title': 'ಭಾಷೆಯ ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
      'description':
          'ಬೆಂಬಲಿತ ಆ್ಯಪ್ ಪರದೆಗಳಿಗಾಗಿ ನಿಮ್ಮ ಆದ್ಯತೆಯ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ.',
      'available': 'ಲಭ್ಯವಿರುವ ಭಾಷೆಗಳು',
      'count': '{count} ಭಾಷೆಗಳು',
      'saving': 'ಭಾಷೆಯ ಆಯ್ಕೆಯನ್ನು ಉಳಿಸಲಾಗುತ್ತಿದೆ...',
      'note': 'ಅನುವಾದ ಲಭ್ಯವಿರುವ ಪರದೆಗಳಲ್ಲಿ ಅನುವಾದಿತ ಪಠ್ಯ ಕಾಣಿಸುತ್ತದೆ. AI ಉತ್ತರಗಳಿಗೆ ಬ್ಯಾಕೆಂಡ್ ಭಾಷಾ ಬೆಂಬಲ ಅಗತ್ಯ.',
      'selected': 'ಆಯ್ಕೆ ಮಾಡಿದ ಭಾಷೆ: {language}',
      'save_failed': 'ಭಾಷೆಯ ಆಯ್ಕೆಯನ್ನು ಉಳಿಸಲಾಗಲಿಲ್ಲ.',
    },
    AppLanguage.malayalam: {
      'title': 'ഭാഷാ ക്രമീകരണങ്ങൾ',
      'description':
          'പിന്തുണയുള്ള ആപ്പ് സ്ക്രീനുകൾക്കായി ഇഷ്ടമുള്ള ഭാഷ തിരഞ്ഞെടുക്കുക.',
      'available': 'ലഭ്യമായ ഭാഷകൾ',
      'count': '{count} ഭാഷകൾ',
      'saving': 'ഭാഷാ മുൻഗണന സംരക്ഷിക്കുന്നു...',
      'note': 'വിവർത്തനം ലഭ്യമായ സ്ക്രീനുകളിൽ വിവർത്തനം ചെയ്ത വാചകം കാണിക്കും. AI മറുപടികൾക്ക് ബാക്കെൻഡ് ഭാഷാ പിന്തുണ ആവശ്യമാണ്.',
      'selected': 'തിരഞ്ഞെടുത്ത ഭാഷ: {language}',
      'save_failed': 'ഭാഷാ മുൻഗണന സംരക്ഷിക്കാനായില്ല.',
    },
    AppLanguage.punjabi: {
      'title': 'ਭਾਸ਼ਾ ਸੈਟਿੰਗਾਂ',
      'description': 'ਸਮਰਥਿਤ ਐਪ ਸਕ੍ਰੀਨਾਂ ਲਈ ਆਪਣੀ ਪਸੰਦੀਦਾ ਭਾਸ਼ਾ ਚੁਣੋ।',
      'available': 'ਉਪਲਬਧ ਭਾਸ਼ਾਵਾਂ',
      'count': '{count} ਭਾਸ਼ਾਵਾਂ',
      'saving': 'ਭਾਸ਼ਾ ਦੀ ਪਸੰਦ ਸੰਭਾਲੀ ਜਾ ਰਹੀ ਹੈ...',
      'note': 'ਜਿੱਥੇ ਅਨੁਵਾਦ ਉਪਲਬਧ ਹਨ, ਉੱਥੇ ਅਨੁਵਾਦਿਤ ਲੇਬਲ ਦਿਖਣਗੇ। AI ਜਵਾਬਾਂ ਲਈ ਬੈਕਐਂਡ ਭਾਸ਼ਾ ਸਹਾਇਤਾ ਲੋੜੀਂਦੀ ਹੈ।',
      'selected': 'ਚੁਣੀ ਗਈ ਭਾਸ਼ਾ: {language}',
      'save_failed': 'ਭਾਸ਼ਾ ਦੀ ਪਸੰਦ ਸੰਭਾਲੀ ਨਹੀਂ ਜਾ ਸਕੀ।',
    },
    AppLanguage.odia: {
      'title': 'ଭାଷା ସେଟିଂସ୍',
      'description': 'ସମର୍ଥିତ ଆପ୍ ସ୍କ୍ରିନ୍ ପାଇଁ ଆପଣଙ୍କ ପସନ୍ଦର ଭାଷା ବାଛନ୍ତୁ।',
      'available': 'ଉପଲବ୍ଧ ଭାଷା',
      'count': '{count}ଟି ଭାଷା',
      'saving': 'ଭାଷା ପସନ୍ଦ ସଂରକ୍ଷଣ ହେଉଛି...',
      'note': 'ଅନୁବାଦ ଉପଲବ୍ଧ ଥିବା ସ୍ଥାନରେ ଅନୁବାଦିତ ଲେବଲ୍ ଦେଖାଯିବ। AI ଉତ୍ତର ପାଇଁ ବ୍ୟାକେଣ୍ଡ୍ ଭାଷା ସମର୍ଥନ ଆବଶ୍ୟକ।',
      'selected': 'ବଛାଯାଇଥିବା ଭାଷା: {language}',
      'save_failed': 'ଭାଷା ପସନ୍ଦ ସଂରକ୍ଷଣ ହୋଇପାରିଲା ନାହିଁ।',
    },
    AppLanguage.assamese: {
      'title': 'ভাষাৰ ছেটিংছ',
      'description': 'সমৰ্থিত এপ স্ক্ৰীনৰ বাবে আপোনাৰ পছন্দৰ ভাষা বাছনি কৰক।',
      'available': 'উপলব্ধ ভাষাসমূহ',
      'count': '{count}টা ভাষা',
      'saving': 'ভাষাৰ পছন্দ সংৰক্ষণ কৰা হৈছে...',
      'note': 'অনুবাদ উপলব্ধ থকা স্ক্ৰীনত অনুবাদিত লেখা দেখা যাব। AI উত্তৰৰ বাবে বেকএণ্ডৰ ভাষা সমৰ্থন লাগিব।',
      'selected': 'নিৰ্বাচিত ভাষা: {language}',
      'save_failed': 'ভাষাৰ পছন্দ সংৰক্ষণ কৰিব পৰা নগ’ল।',
    },
  };

  static const Map<AppLanguage, String> _englishNames = {
    AppLanguage.english: 'English',
    AppLanguage.hindi: 'Hindi',
    AppLanguage.gujarati: 'Gujarati',
    AppLanguage.marathi: 'Marathi',
    AppLanguage.bengali: 'Bengali',
    AppLanguage.tamil: 'Tamil',
    AppLanguage.telugu: 'Telugu',
    AppLanguage.kannada: 'Kannada',
    AppLanguage.malayalam: 'Malayalam',
    AppLanguage.punjabi: 'Punjabi',
    AppLanguage.odia: 'Odia',
    AppLanguage.assamese: 'Assamese',
  };

  String _label(String key, String englishFallback) {
    final languageLabels = _labels[_service.language];
    return languageLabels?[key] ??
        _labels[AppLanguage.english]?[key] ??
        englishFallback;
  }

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.load();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_service.isSaving) return;

    await _service.setLanguage(language);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'selected',
              'Selected: {language}',
            ).replaceAll('{language}', language.displayName),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildLanguageTile(AppLanguage language) {
    final selected = _service.language == language;

    return Card(
      elevation: selected ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: selected ? Colors.green.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Colors.green.shade600 : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<AppLanguage>(
        value: language,
        groupValue: _service.language,
        onChanged: _service.isSaving
            ? null
            : (value) {
                if (value != null) _selectLanguage(value);
              },
        activeColor: Colors.green.shade700,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          language.displayName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _englishNames[language] ?? language.englishName,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        secondary: CircleAvatar(
          backgroundColor: selected
              ? Colors.green.shade100
              : Colors.grey.shade100,
          child: Text(
            language.code.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languages = AppLanguage.values;

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(_label('title', 'Language Settings')),
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.green.shade500],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.translate, color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _service.translate('choose_language') ==
                                    'choose_language'
                                ? 'Choose your language'
                                : _service.translate('choose_language'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _label(
                              'description',
                              'Choose your preferred language for supported app screens.',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label('available', 'Available languages'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _label(
                      'count',
                      '{count} languages',
                    ).replaceAll('{count}', '${languages.length}'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...languages.map(_buildLanguageTile),
              if (_service.isSaving) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(_label('saving', 'Saving language preference...')),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _label(
                          'note',
                          'Translated labels appear where translations are available. AI responses depend on backend language support.',
                        ),
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
