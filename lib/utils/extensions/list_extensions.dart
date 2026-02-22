extension ListExtensions<T> on List<T> {
  /// Returns a new list with the order of the elements shifted by the provided [amount].
  List<T> shift(int amount) {
    if (isEmpty || amount == 0) return this;
    final sublist = this.sublist(amount);
    final head = this.sublist(0, amount);
    return [...sublist, ...head];
  }
}
