class MockUser {
  final int id;
  final String name;
  final String email;
  final String disabilityType;

  const MockUser({
    required this.id,
    required this.name,
    required this.email,
    required this.disabilityType,
  });
}

class MockLesson {
  final int externalActivityId;
  final String title;
  final String subtitle;
  final String content;
  final String activityType;

  const MockLesson({
    required this.externalActivityId,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.activityType,
  });
}

class MockDataProvider {
  static const MockUser currentUser = MockUser(
    id: 12,
    name: 'Juan Perez',
    email: 'juan.perez@example.com',
    disabilityType: 'none',
  );

  static const List<MockUser> availableUsers = [
    currentUser,
    MockUser(
      id: 13,
      name: 'Maria Garcia',
      email: 'maria.garcia@example.com',
      disabilityType: 'visual_impairment',
    ),
    MockUser(
      id: 14,
      name: 'Carlos Lopez',
      email: 'carlos.lopez@example.com',
      disabilityType: 'hearing_impairment',
    ),
  ];

  static const List<MockLesson> lessons = [
    MockLesson(
      externalActivityId: 101,
      title: 'Historia de la Inteligencia Artificial',
      subtitle: 'Los origenes y evolucion de la IA',
      content: '''
La Inteligencia Artificial (IA) es una rama de la informatica que busca crear 
sistemas capaces de realizar tareas que normalmente requieren inteligencia humana.

Los origenes de la IA se remontan a la decada de 1950, cuando Alan Turing 
propuso la pregunta "Pueden pensar las maquinas?" en su famoso articulo 
"Computing Machinery and Intelligence".

En 1956, John McCarthy acuno el termino "Inteligencia Artificial" durante 
la Conferencia de Dartmouth, considerada el nacimiento oficial del campo.

Desde entonces, la IA ha evolucionado enormemente:

- 1950s-1960s: Primeros programas de IA, como el Logic Theorist
- 1970s-1980s: Sistemas expertos y el primer "invierno de la IA"
- 1990s-2000s: Machine Learning y Deep Blue vence a Kasparov
- 2010s-presente: Deep Learning, GPT, y la era de la IA generativa

Hoy en dia, la IA esta presente en nuestras vidas diarias: desde asistentes 
virtuales hasta sistemas de recomendacion y vehiculos autonomos.
      ''',
      activityType: 'reading',
    ),
    MockLesson(
      externalActivityId: 102,
      title: 'Fundamentos de Matematicas',
      subtitle: 'Numeros y operaciones basicas',
      content: '''
Los numeros son la base de las matematicas. En esta leccion aprenderemos 
sobre los diferentes tipos de numeros y sus operaciones.

TIPOS DE NUMEROS:

1. Numeros Naturales (N): 1, 2, 3, 4, 5...
   Son los numeros que usamos para contar.

2. Numeros Enteros (Z): ...-3, -2, -1, 0, 1, 2, 3...
   Incluyen los naturales, el cero y los negativos.

3. Numeros Racionales (Q): 1/2, 0.75, -3/4
   Pueden expresarse como fraccion de dos enteros.

4. Numeros Reales (R): pi, raiz de 2, e
   Incluyen todos los anteriores mas los irracionales.

OPERACIONES BASICAS:

- Suma (+): Combinar cantidades
- Resta (-): Encontrar la diferencia
- Multiplicacion (x): Suma repetida
- Division (/): Repartir en partes iguales

EJERCICIOS:
1. 15 + 27 = 42
2. 45 - 18 = 27
3. 6 x 7 = 42
4. 72 / 8 = 9
      ''',
      activityType: 'reading',
    ),
    MockLesson(
      externalActivityId: 103,
      title: 'Introduccion a Python',
      subtitle: 'Variables y tipos de datos',
      content: '''
Python es un lenguaje de programacion versatil y facil de aprender.
Es ideal para principiantes y tambien usado por expertos.

VARIABLES:

Las variables son contenedores para almacenar datos:

nombre = "Juan"
edad = 25
altura = 1.75
es_estudiante = True

TIPOS DE DATOS:

1. str (string): Cadenas de texto
   ejemplo = "Hola mundo"

2. int (integer): Numeros enteros
   cantidad = 42

3. float: Numeros decimales
   precio = 19.99

4. bool (boolean): Verdadero o Falso
   activo = True

5. list: Listas de elementos
   frutas = ["manzana", "pera", "uva"]

6. dict (dictionary): Pares clave-valor
   persona = {"nombre": "Ana", "edad": 30}

EJEMPLO COMPLETO:

# Programa que saluda al usuario
nombre = input("Como te llamas? ")
edad = int(input("Cuantos años tienes? "))
print(f"Hola {nombre}, tienes {edad} años")
      ''',
      activityType: 'reading',
    ),
    MockLesson(
      externalActivityId: 104,
      title: 'El Sistema Solar',
      subtitle: 'Planetas y cuerpos celestes',
      content: '''
El Sistema Solar es nuestro vecindario cosmico, formado hace 
aproximadamente 4,600 millones de años.

EL SOL:
Es nuestra estrella, contiene el 99.86% de la masa del sistema.
Temperatura superficial: 5,500 grados Celsius.

LOS PLANETAS (en orden desde el Sol):

1. MERCURIO
   - Planeta mas pequeño y cercano al Sol
   - Sin atmosfera significativa
   - Un dia dura 59 dias terrestres

2. VENUS
   - Similar en tamaño a la Tierra
   - Atmosfera densa de CO2
   - El planeta mas caliente (462 C)

3. TIERRA
   - Nuestro hogar
   - Unico planeta con agua liquida conocido
   - Atmosfera perfecta para la vida

4. MARTE
   - El planeta rojo
   - Tiene el volcan mas grande: Olympus Mons
   - Objetivo de exploracion humana

5. JUPITER
   - El planeta mas grande
   - Gran Mancha Roja: tormenta de 400 años
   - Tiene 95 lunas conocidas

6. SATURNO
   - Famoso por sus anillos
   - Densidad menor que el agua
   - Luna Titan tiene atmosfera

7. URANO
   - Gira de lado (inclinacion 98 grados)
   - Color azul verdoso
   - 27 lunas conocidas

8. NEPTUNO
   - El mas lejano
   - Vientos de 2,000 km/h
   - Luna Triton orbita en sentido contrario
      ''',
      activityType: 'reading',
    ),
  ];

  static MockLesson? getLessonById(int externalActivityId) {
    try {
      return lessons.firstWhere(
            (lesson) => lesson.externalActivityId == externalActivityId,
      );
    } catch (_) {
      return null;
    }
  }
}