import 'dart:html' as html;

void injectWebScript(String src, void Function() onLoad) {
  final existing = html.document.getElementById('google-maps-sdk-script');
  if (existing != null) {
    onLoad();
    return;
  }
  final script = html.ScriptElement()
    ..id = 'google-maps-sdk-script'
    ..src = src
    ..async = true
    ..defer = true;
  script.onLoad.listen((_) => onLoad());
  html.document.head!.append(script);
}
