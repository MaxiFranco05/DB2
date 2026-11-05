/**
 * consultas_mongodb.js
 * 
 * Asignatura: Bases de Datos II - Tecnicatura Universitaria en Programación
 * Proyecto: Food Store - Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
 * Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
 * Repositorio: https://github.com/MaxiFranco05/DB2
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
// FASE 0: CARGA IDEMPOTENTE DE LOS 5 PEDIDOS REALES MIESTRADOS DE POSTGRESQL
// --------------------------------------------------------------------------
// Muestra tomada de 'foodstore' (IDs: 756504 a 756508, Cliente: 80584).
// Se congela el precio histórico y se excluyen contraseñas por directiva de seguridad.

db.pedidos.deleteMany({
  pedido_id_origen: { $in: [756504, 756505, 756506, 756507, 756508] }
});

const resultadoCarga = db.pedidos.insertMany([
  {
    pedido_id_origen: 756504,
    fecha: ISODate("2025-11-09T03:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "EFECTIVO",
    total: 4517.28,
    cliente: {
      usuario_id_origen: 80584,
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: 236648,
        nombre: "Producto 36648",
        cantidad: 2,
        precio_unitario_historico: 1552.64,
        subtotal: 3105.28
      },
      {
        producto_id_origen: 220320,
        nombre: "Producto 20320",
        cantidad: 2,
        precio_unitario_historico: 706.00,
        subtotal: 1412.00
      }
    ]
  },
  {
    pedido_id_origen: 756505,
    fecha: ISODate("2026-06-08T03:00:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "TARJETA",
    total: 16307.74,
    cliente: {
      usuario_id_origen: 80584,
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: 243882,
        nombre: "Producto 43882",
        cantidad: 2,
        precio_unitario_historico: 3628.43,
        subtotal: 7256.86
      },
      {
        producto_id_origen: 236648,
        nombre: "Producto 36648",
        cantidad: 3,
        precio_unitario_historico: 1552.64,
        subtotal: 4657.92
      },
      {
        producto_id_origen: 220320,
        nombre: "Producto 20320",
        cantidad: 3,
        precio_unitario_historico: 706.00,
        subtotal: 2118.00
      },
      {
        producto_id_origen: 221809,
        nombre: "Producto 21809",
        cantidad: 4,
        precio_unitario_historico: 568.74,
        subtotal: 2274.96
      }
    ]
  },
  {
    pedido_id_origen: 756506,
    fecha: ISODate("2026-04-17T03:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "TRANSFERENCIA",
    total: 18092.69,
    cliente: {
      usuario_id_origen: 80584,
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: 221809,
        nombre: "Producto 21809",
        cantidad: 2,
        precio_unitario_historico: 568.74,
        subtotal: 1137.48
      },
      {
        producto_id_origen: 220320,
        nombre: "Producto 20320",
        cantidad: 2,
        precio_unitario_historico: 706.00,
        subtotal: 1412.00
      },
      {
        producto_id_origen: 236648,
        nombre: "Producto 36648",
        cantidad: 3,
        precio_unitario_historico: 1552.64,
        subtotal: 4657.92
      },
      {
        producto_id_origen: 243882,
        nombre: "Producto 43882",
        cantidad: 3,
        precio_unitario_historico: 3628.43,
        subtotal: 10885.29
      }
    ]
  },
  {
    pedido_id_origen: 756507,
    fecha: ISODate("2026-06-07T03:00:00Z"),
    estado: "PENDIENTE",
    forma_pago: "EFECTIVO",
    total: 15128.05,
    cliente: {
      usuario_id_origen: 80584,
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: 221809,
        nombre: "Producto 21809",
        cantidad: 2,
        precio_unitario_historico: 568.74,
        subtotal: 1137.48
      },
      {
        producto_id_origen: 236648,
        nombre: "Producto 36648",
        cantidad: 2,
        precio_unitario_historico: 1552.64,
        subtotal: 3105.28
      },
      {
        producto_id_origen: 243882,
        nombre: "Producto 43882",
        cantidad: 3,
        precio_unitario_historico: 3628.43,
        subtotal: 10885.29
      }
    ]
  },
  {
    pedido_id_origen: 756508,
    fecha: ISODate("2025-11-14T03:00:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    total: 13052.26,
    cliente: {
      usuario_id_origen: 80584,
      nombre_completo: "Usuario584 Apellido584",
      mail: "usuario584@test.com"
    },
    items: [
      {
        producto_id_origen: 243882,
        nombre: "Producto 43882",
        cantidad: 2,
        precio_unitario_historico: 3628.43,
        subtotal: 7256.86
      },
      {
        producto_id_origen: 221809,
        nombre: "Producto 21809",
        cantidad: 2,
        precio_unitario_historico: 568.74,
        subtotal: 1137.48
      },
      {
        producto_id_origen: 236648,
        nombre: "Producto 36648",
        cantidad: 3,
        precio_unitario_historico: 1552.64,
        subtotal: 4657.92
      }
    ]
  }
]);

print(`[OK] Insertados ${resultadoCarga.insertedCount} documentos de muestra en 'foodstore_nosql.pedidos'.\n`);

// --------------------------------------------------------------------------
// CONSIGNA 4 - CONSULTAS EN MONGODB
// --------------------------------------------------------------------------

// Q-M1: Mostrar todos los pedidos, incluyendo su identificador de origen y estado (proyección explícita)
print("--- [Q-M1] Todos los pedidos (identificador y estado) ---");
const res_qm1 = db.pedidos.find(
  {},
  { pedido_id_origen: 1, estado: 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm1);
print(`Total recuperados Q-M1: ${res_qm1.length} documentos (Esperado: 5).\n`);

// Q-M2: Filtrar pedidos por un estado existente en los datos migrados ('CONFIRMADO')
print("--- [Q-M2] Filtro por estado 'CONFIRMADO' ---");
const res_qm2 = db.pedidos.find(
  { estado: "CONFIRMADO" },
  { pedido_id_origen: 1, estado: 1, fecha: 1, total: 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm2);
print(`Total recuperados Q-M2: ${res_qm2.length} documentos (Esperado: 2 - IDs: [756505, 756508]).\n`);

// Q-M3: Buscar pedidos que contengan un producto determinado (243882) dentro del arreglo de líneas
print("--- [Q-M3] Filtro por producto embebido en items (producto_id_origen = 243882) ---");
const res_qm3 = db.pedidos.find(
  { "items.producto_id_origen": 243882 },
  { pedido_id_origen: 1, estado: 1, "items.$": 1, _id: 0 }
).sort({ pedido_id_origen: 1 }).toArray();
printjson(res_qm3);
print(`Total recuperados Q-M3: ${res_qm3.length} documentos (Esperado: 4 - IDs: [756505, 756506, 756507, 756508]).\n`);

// Q-M4: Buscar pedidos cuyo total sea superior a un importe elegido ($15.000)
// Justificación del umbral: Distribuye la muestra entre pedidos chicos (<$15k: 756504 y 756508)
// y pedidos medianos/grandes (>$15k: 756505, 756506 y 756507), permitiendo evaluar el operador $gt.
print("--- [Q-M4] Filtro por importe total superior a $15.000 ---");
const res_qm4 = db.pedidos.find(
  { total: { $gt: 15000 } },
  { pedido_id_origen: 1, estado: 1, total: 1, _id: 0 }
).sort({ total: -1 }).toArray();
printjson(res_qm4);
print(`Total recuperados Q-M4: ${res_qm4.length} documentos (Esperado: 3 - IDs: [756506, 756505, 756507]).\n`);

// --------------------------------------------------------------------------
// VALIDACIÓN DE INTEGRIDAD REQUERIDA (RI-M1 y RI-M2)
// --------------------------------------------------------------------------
print("--- [AUDITORÍA RI-M1] Comprobación de consistencia matemática en totales ---");
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
      $expr: { $gt: [{ $abs: "$diferencia" }, 0.01] }
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

print("==========================================================================");
print("  FIN DE EJECUCIÓN - SCRIPT MONGODB COMPLETADO");
print("==========================================================================\n");
