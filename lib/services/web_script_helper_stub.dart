void injectWebScript(String src, void Function() onLoad) {
  // No-op for non-web platforms, call onLoad immediately
  onLoad();
}
