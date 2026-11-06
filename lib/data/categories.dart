class Categories {
  static const all = 'Toate';
  static const favorites = 'Favorite';
  static const recent = 'Recente';
  static const other = 'Altele';

  static const _map = {
    'general': 'Generaliste',
    'news': 'Știri',
    'sports': 'Sport',
    'music': 'Muzică',
    'religious': 'Religie',
    'culture': 'Cultură',
    'kids': 'Copii',
    'animation': 'Copii',
    'movies': 'Filme',
    'series': 'Seriale',
    'entertainment': 'Divertisment',
    'documentary': 'Documentare',
    'education': 'Educație',
    'lifestyle': 'Lifestyle',
    'cooking': 'Gastronomie',
    'travel': 'Călătorii',
    'business': 'Business',
    'comedy': 'Comedie',
    'science': 'Știință',
    'weather': 'Meteo',
    'auto': 'Auto',
    'outdoor': 'Natură',
    'family': 'Familie',
    'legislative': 'Instituții',
    'shop': 'Teleshopping',
    'classic': 'Clasice',
  };

  static String localize(String group) => _map[group.toLowerCase()] ?? group;
}
