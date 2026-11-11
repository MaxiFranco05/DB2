/**
 * consultas_mongodb.js
 * 
 * Asignatura: Bases de Datos II - Tecnicatura Universitaria en Programación
 * Proyecto: Food Store - Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
 * Comisión: C3 · Prof. Sergio Neira
 * Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
 * Motor: MongoDB 7+ (mongosh)
 * 
 * Especificación formal de referencia: SPEC_U7.md
 * 
 * Ejecución:
 *   mongosh --file consultas_mongodb.js
 *   (o desde mongosh: load("consultas_mongodb.js"))
 */

// Conexión y selección de base de datos
db = db.getSiblingDB("foodstore_nosql");

print("\n==========================================================================");
print("  FOOD STORE - MIGRACIÓN Y CONSULTAS DOCUMENTALES EN MONGODB (UNIDAD 7)");
print("==========================================================================\n");

// --------------------------------------------------------------------------
// FASE 0: CREACIÓN DE COLECCIÓN CON VALIDADOR $jsonSchema (Decimal128 y RI-M2)
// --------------------------------------------------------------------------
try {
  db.createCollection("pedidos", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["pedido_id_origen", "fecha", "estado", "forma_pago", "total", "cliente", "items"],
        properties: {
          pedido_id_origen: { bsonType: "int", description: "ID relacional obligatorio" },
          fecha: { bsonType: "date", description: "Fecha ISO obligatoria" },
          estado: { enum: ["PENDIENTE", "CONFIRMADO", "TERMINADO", "CANCELADO"], description: "Estado restringido" },
          forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"], description: "Forma de pago" },
          total: { bsonType: "decimal", description: "Total exacto en Decimal128" },
          cliente: {
            bsonType: "object",
            required: ["usuario_id_origen", "nombre_completo", "mail"],
            properties: {
              usuario_id_origen: { bsonType: "int" },
              nombre_completo: { bsonType: "string" },
              mail: { bsonType: "string" }
            }
          },
          items: {
            bsonType: "array",
            minItems: 1,
            description: "RI-M2: El pedido debe contener al menos 1 línea",
            items: {
              bsonType: "object",
              required: ["producto_id_origen", "nombre", "cantidad", "precio_unitario_historico", "subtotal"],
              properties: {
                producto_id_origen: { bsonType: "int" },
                nombre: { bsonType: "string" },
                cantidad: { bsonType: "int" },
                precio_unitario_historico: { bsonType: "decimal" },
                subtotal: { bsonType: "decimal" }
              }
            }
          }
        }
      }
    }
  });
  print("[OK] Colección 'pedidos' creada con validador $jsonSchema y tipos Decimal128.");
} catch (e) {
  print("[INFO] Colección 'pedidos' ya existente; se mantiene validador activo.");
}

// --------------------------------------------------------------------------
// FASE 1: CARGA IDEMPOTENTE CON IMPORTES EN Decimal128 (NumberDecimal)
// --------------------------------------------------------------------------
// Muestra tomada de 'foodstore' (IDs: 756504 a 756508, Cliente: 80584).
// Se congelan precios con NumberDecimal y se excluyen contraseñas de clientes.

db.pedidos.deleteMany({
  pedido_id_origen: { $in: [756504, 756505, 756506, 756507, 756508] }
});

const resultadoCarga = db.pedidos.insertMany([
  {
    pedido_id_origen: NumberInt(756504),
    fecha: ISODate("2025-11-09T03:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "EFECTIVO",
    total: NumberDecimal("4517.28"),
    cliente: {
      usuario_id_origen: NumberInt(80584),
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: NumberInt(236648),
        nombre: "Producto 36648",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("1552.64"),
        subtotal: NumberDecimal("3105.28")
      },
      {
        producto_id_origen: NumberInt(220320),
        nombre: "Producto 20320",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("706.00"),
        subtotal: NumberDecimal("1412.00")
      }
    ]
  },
  {
    pedido_id_origen: NumberInt(756505),
    fecha: ISODate("2026-06-08T03:00:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "TARJETA",
    total: NumberDecimal("16307.74"),
    cliente: {
      usuario_id_origen: NumberInt(80584),
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: NumberInt(243882),
        nombre: "Producto 43882",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("3628.43"),
        subtotal: NumberDecimal("7256.86")
      },
      {
        producto_id_origen: NumberInt(236648),
        nombre: "Producto 36648",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("1552.64"),
        subtotal: NumberDecimal("4657.92")
      },
      {
        producto_id_origen: NumberInt(220320),
        nombre: "Producto 20320",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("706.00"),
        subtotal: NumberDecimal("2118.00")
      },
      {
        producto_id_origen: NumberInt(221809),
        nombre: "Producto 21809",
        cantidad: NumberInt(4),
        precio_unitario_historico: NumberDecimal("568.74"),
        subtotal: NumberDecimal("2274.96")
      }
    ]
  },
  {
    pedido_id_origen: NumberInt(756506),
    fecha: ISODate("2026-04-17T03:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "TRANSFERENCIA",
    total: NumberDecimal("18092.69"),
    cliente: {
      usuario_id_origen: NumberInt(80584),
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: NumberInt(221809),
        nombre: "Producto 21809",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("568.74"),
        subtotal: NumberDecimal("1137.48")
      },
      {
        producto_id_origen: NumberInt(220320),
        nombre: "Producto 20320",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("706.00"),
        subtotal: NumberDecimal("1412.00")
      },
      {
        producto_id_origen: NumberInt(236648),
        nombre: "Producto 36648",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("1552.64"),
        subtotal: NumberDecimal("4657.92")
      },
      {
        producto_id_origen: NumberInt(243882),
        nombre: "Producto 43882",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("3628.43"),
        subtotal: NumberDecimal("10885.29")
      }
    ]
  },
  {
    pedido_id_origen: NumberInt(756507),
    fecha: ISODate("2026-06-07T03:00:00Z"),
    estado: "PENDIENTE",
    forma_pago: "EFECTIVO",
    total: NumberDecimal("15128.05"),
    cliente: {
      usuario_id_origen: NumberInt(80584),
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: NumberInt(221809),
        nombre: "Producto 21809",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("568.74"),
        subtotal: NumberDecimal("1137.48")
      },
      {
        producto_id_origen: NumberInt(236648),
        nombre: "Producto 36648",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("1552.64"),
        subtotal: NumberDecimal("3105.28")
      },
      {
        producto_id_origen: NumberInt(243882),
        nombre: "Producto 43882",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("3628.43"),
        subtotal: NumberDecimal("10885.29")
      }
    ]
  },
  {
    pedido_id_origen: NumberInt(756508),
    fecha: ISODate("2025-11-14T03:00:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    total: NumberDecimal("13052.26"),
    cliente: {
      usuario_id_origen: NumberInt(80584),
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: NumberInt(243882),
        nombre: "Producto 43882",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("3628.43"),
        subtotal: NumberDecimal("7256.86")
      },
      {
        producto_id_origen: NumberInt(221809),
        nombre: "Producto 21809",
        cantidad: NumberInt(2),
        precio_unitario_historico: NumberDecimal("568.74"),
        subtotal: NumberDecimal("1137.48")
      },
      {
        producto_id_origen: NumberInt(236648),
        nombre: "Producto 36648",
        cantidad: NumberInt(3),
        precio_unitario_historico: NumberDecimal("1552.64"),
        subtotal: NumberDecimal("4657.92")
      }
    ]
  }
]);

print(`[OK] Insertados ${resultadoCarga.insertedCount} documentos de muestra en 'foodstore_nosql.pedidos'.\n`);

// --------------------------------------------------------------------------
// CONSIGNA 4 - CONSULTAS EN MONGODB
// --------------------------------------------------------------------------

// Q-M1: Mostrar todos los pedidos, incluyendo su identificador de origen y estado
print("--- [Q-M1] Todos los pedidos (identificador y estado) ---");
const res_qm1 = db.pedidos.find(
  {},
  { pedido_id_origen: 1, estado: 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm1);
print(`Total recuperados Q-M1: ${res_qm1.length} documentos (Esperado: 5).\n`);

// Q-M2: Filtrar pedidos por estado 'CONFIRMADO'
print("--- [Q-M2] Filtro por estado 'CONFIRMADO' ---");
const res_qm2 = db.pedidos.find(
  { estado: "CONFIRMADO" },
  { pedido_id_origen: 1, estado: 1, fecha: 1, total: 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm2);
print(`Total recuperados Q-M2: ${res_qm2.length} documentos (Esperado: 2 - IDs: [756505, 756508]).\n`);

// Q-M3: Buscar pedidos con producto 243882 embebido en items
print("--- [Q-M3] Filtro por producto embebido en items (producto_id_origen = 243882) ---");
const res_qm3 = db.pedidos.find(
  { "items.producto_id_origen": 243882 },
  { pedido_id_origen: 1, estado: 1, "items.$": 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm3);
print(`Total recuperados Q-M3: ${res_qm3.length} documentos (Esperado: 4 - IDs: [756505, 756506, 756507, 756508]).\n`);

// Q-M4: Buscar pedidos cuyo total sea superior a $15.000 utilizando Decimal128
print("--- [Q-M4] Filtro por importe total superior a $15.000 (Decimal128) ---");
const res_qm4 = db.pedidos.find(
  { total: { $gt: NumberDecimal("15000.00") } },
  { pedido_id_origen: 1, estado: 1, total: 1, _id: 0 }
).sort({ total: -1 }).toArray();
printjson(res_qm4);
print(`Total recuperados Q-M4: ${res_qm4.length} documentos (Esperado: 3 - IDs: [756506, 756505, 756507]).\n`);

// --------------------------------------------------------------------------
// VALIDACIÓN DE INTEGRIDAD REQUERIDA (RI-M1 y RI-M2)
// --------------------------------------------------------------------------
print("--- [AUDITORÍA RI-M1] Comprobación de consistencia matemática en totales (Decimal128) ---");
const inconsistenciasTotales = db.pedidos.aggregate([
  {
    $project: {
      pedido_id_origen: 1,
      total_guardado: "$total",
      total_calculado: { $sum: "$items.subtotal" },
      diferencia: { $subtract: ["$total", { $sum: "$items.subtotal" }] }
    }
  },
  {
    $match: {
      $expr: { $gt: [{ $abs: "$diferencia" }, NumberDecimal("0.01")] }
    }
  }
]).toArray();

if (inconsistenciasTotales.length === 0) {
  print("✅ RI-M1 Verificada: 0 inconsistencias de precios/totales (100% de coherencia matemática).");
} else {
  print("❌ RI-M1 Falló: discrepancias encontradas en:", inconsistenciasTotales);
}

print("\n--- [AUDITORÍA RI-M2] Comprobación de atomicidad y no vaciedad de líneas ---");
const pedidosSinLineas = db.pedidos.find({
  $or: [
    { items: { $exists: false } },
    { items: null },
    { items: { $size: 0 } }
  ]
}).toArray();

if (pedidosSinLineas.length === 0) {
  print("✅ RI-M2 Verificada: 0 pedidos huérfanos o sin ítems (100% de documentos válidos).\n");
} else {
  print("❌ RI-M2 Falló: pedidos sin líneas detectados:", pedidosSinLineas);
}

// --------------------------------------------------------------------------
// LABORATORIO IA: PRUEBA DE ÍNDICE ÚNICO E ÍNDICES SECUNDARIOS
// --------------------------------------------------------------------------
print("--- [LABORATORIO IA] Prueba de contraste de recomendación de IA (Índice Único) ---");
db.pedidos.createIndex({ pedido_id_origen: 1 }, { unique: true });
db.pedidos.createIndex({ estado: 1 });
db.pedidos.createIndex({ "items.producto_id_origen": 1 });

try {
  db.pedidos.insertOne({
    pedido_id_origen: NumberInt(756505), // Ya existe
    fecha: new Date(),
    estado: "PENDIENTE",
    forma_pago: "EFECTIVO",
    total: NumberDecimal("1000.00"),
    cliente: { usuario_id_origen: NumberInt(80584), nombre_completo: "Test", mail: "test@test.com" },
    items: [{ producto_id_origen: NumberInt(1), nombre: "Test", cantidad: NumberInt(1), precio_unitario_historico: NumberDecimal("1000.00"), subtotal: NumberDecimal("1000.00") }]
  });
  print("❌ Error: Se permitió duplicado.");
} catch (err) {
  print("✅ Contraste de IA verificado en laboratorio: Rechazo exitoso de clave duplicada (E11000).");
}

print("\n==========================================================================");
print("  FIN DE EJECUCIÓN - SCRIPT MONGODB COMPLETADO");
print("==========================================================================\n");
