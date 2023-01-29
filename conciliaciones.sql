-- Crear tabla CLAP

CREATE TABLE CLAP (
    inicio06_tarjeta VARCHAR,
    final4_tarjeta VARCHAR,
    tipo_trx VARCHAR,
    monto DECIMAL,
    fecha_transaccion TIMESTAMP,
    codigo_autorizacion VARCHAR,
    id_banco VARCHAR,
    fecha_recepcion_banco DATE
);

-- Crear tabla Bansur

CREATE TABLE BANSUR (
    tarjeta VARCHAR,
    tipo_trx VARCHAR,
    monto DECIMAL,
    fecha_transaccion VARCHAR,
    codigo_autorizacion VARCHAR,
    id_adquiriente VARCHAR,
    fecha_recepcion DATE
);

/**
 Tiendo encuenta lo descrito por el enunciado:
  "Una transacción regular se evidencia en la base de datos como un PAGO; se debe tener
   en cuenta que un mismo ID puede también tomar estado de Cancelación, Chargeback u Otros casos."
 Para esto creamos un id que nos permita identificar cada transacción en cada base da
 datos (CLAP Y BANSUR) ya que en los datasets no viene dicho id, para lograrlo podemos usar el
 número de la tarjeta, el código de autorización, el monto y el id del adquiriente como criterios
 de unicidad, esto permitirá identificar cada transacción agrupando por estos campos.
*/
WITH transacciones AS (
    SELECT tarjeta, codigo_autorizacion, abs(monto) AS monto_abs, id_adquiriente
    FROM bansur
    GROUP BY tarjeta, codigo_autorizacion, abs(monto), id_adquiriente
    ORDER BY tarjeta
)
SELECT row_number() over (), *
FROM transacciones
;

- Agregamos una columna para asignar el identificador de la transacción (id)
ALTER TABLE bansur
ADD COLUMN id numeric;


-- Seguidamente, establecemos el valor de los ids usando el criterio de unicidad antes expuesto
WITH transacciones AS (
    SELECT tarjeta, codigo_autorizacion, abs(monto) AS monto_abs, id_adquiriente
    FROM bansur
    GROUP BY tarjeta, codigo_autorizacion, abs(monto), id_adquiriente
    ORDER BY tarjeta
),
transacciones_con_id AS (
    SELECT row_number() over () as id, *
    FROM transacciones
)
UPDATE BANSUR AS b
SET id = t.id
FROM transacciones_con_id AS t
WHERE b.tarjeta = t.tarjeta
    AND b.codigo_autorizacion = t.codigo_autorizacion
    AND abs(b.monto) = t.monto_abs
    AND b.id_adquiriente = t.id_adquiriente;

/**
  Simetrik considera una partida como conciliable toda
  aquella transacción cuyo último estado en la base de datos ordenada por fecha y hora  sea PAGADA.
  De esta manera, procedemos a identificar la fecha mas reciente de una transaccion y su estado como pagada
 */

 CREATE OR REPLACE VIEW bansur_conciliable AS (
     SELECT id,
            tarjeta,
            tipo_trx,
            monto,
            to_date(fecha_transaccion,'YYYYMMDD') AS fecha_transaccion,
            codigo_autorizacion,
            id_adquiriente,
            fecha_recepcion
     FROM (
        SELECT *,
        row_number() OVER (PARTITION BY id ORDER BY fecha_transaccion DESC) AS rn
        FROM bansur
    ) AS r
     WHERE rn = 1 AND tipo_trx = 'PAGO'
);

/**
  Partidas conciliables del cliente CLAP.
  Para esto debemos asignarle un identificador que coincida con los datos en BANSUR
 */

ALTER TABLE clap
ADD COLUMN id numeric;

UPDATE CLAP AS c
SET id = b.id
FROM bansur AS b
WHERE concat(c.inicio06_tarjeta, c.final4_tarjeta) = b.tarjeta
    AND c.codigo_autorizacion = b.codigo_autorizacion
    AND abs(c.monto) = abs(b.monto)
    AND c.id_banco = b.id_adquiriente
;

/**
  Con la siguiente consulta podemos verificar si existen transacciones que les falte asignarle el id
 */
 SELECT COUNT(*)
FROM clap
WHERE id is null
        AND inicio06_tarjeta IS NOT NULL
        AND final4_tarjeta IS NOT NULL
        AND codigo_autorizacion IS NOT NULL
        AND abs(monto) IS NOT NULL
        AND id_banco IS NOT NULL;
/**
  Despues de ejecutar la consulta anterior, el resultado nos dice que hay transacciones (54491) por asignar un id
  ya que no cruzaron con las de banzur pero se puede identificar usando el criterio de unicidad antes mencionado, es
  decir, las columnas tarjeta, codigo de autorizacion, monto y banco, para asignar estos ids usamos la siguiente consulta
 */
 WITH transacciones AS (
    SELECT concat(inicio06_tarjeta, final4_tarjeta) AS tarjeta, codigo_autorizacion, abs(monto) AS monto_abs, id_banco
    FROM clap
    GROUP BY tarjeta, codigo_autorizacion, abs(monto), id_banco
    ORDER BY tarjeta
),
transacciones_con_id AS (
    SELECT row_number() over () + (SELECT MAX(id) FROM bansur) as id, *
    FROM transacciones
)
UPDATE CLAP AS c
SET id = t.id
FROM transacciones_con_id AS t
WHERE c.id IS NULL
    AND concat(c.inicio06_tarjeta, c.final4_tarjeta) = t.tarjeta
    AND c.codigo_autorizacion = t.codigo_autorizacion
    AND abs(c.monto) = t.monto_abs
    AND c.id_banco = t.id_banco;

-- Creamos una vista para calcular la data conciliable con los criterios descritos por Simetrik

CREATE OR REPLACE VIEW clap_conciliable AS (
     SELECT id,
            concat(inicio06_tarjeta,final4_tarjeta) AS tarjeta,
            tipo_trx,
            monto,
            fecha_transaccion::date AS fecha_transaccion,
            codigo_autorizacion,
            id_banco AS id_adquiriente,
            fecha_recepcion_banco AS fecha_recepcion
     FROM (
        SELECT *,
        row_number() OVER (PARTITION BY id ORDER BY fecha_transaccion DESC) AS rn
        FROM clap
        WHERE inicio06_tarjeta IS NOT NULL
            AND final4_tarjeta IS NOT NULL
            AND codigo_autorizacion IS NOT NULL
            AND monto IS NOT NULL
            AND id_banco IS NOT NULL
    ) AS r
     WHERE rn = 1 AND tipo_trx = 'PAGADA'
);
