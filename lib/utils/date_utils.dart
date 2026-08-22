String formatDate(DateTime? date, {String placeholder = 'Select date'}) {
  if (date == null) return placeholder;
  return '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/${date.year}';
}
