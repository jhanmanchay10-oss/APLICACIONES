/// Consejos del día: positivos, prácticos y sin culpa.
const dailyTips = <String>[
  'Llena la mitad de tu plato con verduras de distintos colores.',
  'El agua es la mejor compañera de tus comidas.',
  'Las legumbres son una fuente económica de proteína y fibra.',
  'Una fruta entera aporta más fibra que su jugo.',
  'Cocinar en casa te ayuda a controlar la sal y el azúcar.',
  'Prueba hierbas, limón o especias para dar sabor sin sal extra.',
  'Comer con calma y sin pantallas ayuda a reconocer la saciedad.',
  'Los frutos secos son un buen snack: un puñado es suficiente.',
  'Alterna pescado, huevo, legumbres y aves durante la semana.',
  'Prefiere cereales integrales como avena, quinua o arroz integral.',
  'Leer la etiqueta te ayuda a detectar azúcares añadidos.',
  'Ninguna comida por sí sola define tu alimentación: cuenta el equilibrio.',
  'Planificar las comidas de la semana facilita elegir opciones frescas.',
  'Una ensalada o sopa de verduras al inicio suma nutrientes al plato.',
];

String tipOfTheDay(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return dailyTips[dayOfYear % dailyTips.length];
}
