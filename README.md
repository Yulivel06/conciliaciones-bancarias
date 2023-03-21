

## ¿Qué es una conciliación bancaria?

Se trata de un proceso que permite comparar los valores que la empresa tiene registrados de una cuenta de ahorros o cuenta corriente con los valores que el banco le suministra por medio del extracto bancario, que suele recibirse cada mes.

Es decir, compara información entres dos fuentes de datos en busca de información equivalente.

## Estudio de caso 

Uno de nuestros clientes, CLAP, maneja Datafonos y se encarga de procesar pagos. SIMETRIK es su aliado para comparar las transacciones que se reportan a través de sus dispositivos contra las transacciones que se registran en las liquidaciones bancarias (BANSUR).

Cada vez que el cliente CLAP reporta un pago con su datáfono envía un registro a su base de datos y a la base de datos del adquirente BANSUR. Sin embargo, dada la gran cantidad de pagos que se realizan a diario, CLAP no puede llevar un control efectivo de todas las transacciones realizadas y necesitan verificar que todas las transacciones registradas en su base de datos también se encuentren en la base de BANSUR.

IMPORTANTE: Una transacción regular se evidencia en la base de datos como un PAGO; se debe tener en cuenta que un mismo ID puede también tomar estado de Cancelación, Chargeback u Otros casos. 

Simetrik considera una partida como conciliable toda aquella transacción cuyo último estado en la base de datos ordenada por fecha y hora  sea PAGADA.

Para esto, SIMETRIK comparará para cada transacción campos únicos entre las dos entidades buscando encontrar parejas que sean exactamente iguales bajo las siguientes condiciones:

Que tengan el mismo ID.
Que tenga los mismos 6 primeros dígitos de la tarjeta.
Que tengan los mismos 4 últimos dígitos de la tarjeta.
Que el valor pagado en la transacción sea igual o que su diferencia esté en el rango de más o menos 0.99 pesos.
Que tengan la misma fecha de transacción.

## Empecemos..

1. Puede obtener los dataset de  [BANSUR](https://github.com/Yulivel06/conciliaciones-bancarias/blob/master/BANSUR.csv) y [CLAP](https://github.com/Yulivel06/conciliaciones-bancarias/blob/master/CLAP.csv)

2. Procedemos a crear cada una de las tablas 

Crear tabla CLAP
``` sql
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
``` 
``` sql

Crear tabla Bansur

CREATE TABLE BANSUR (
    tarjeta VARCHAR,
    tipo_trx VARCHAR,
    monto DECIMAL,
    fecha_transaccion VARCHAR,
    codigo_autorizacion VARCHAR,
    id_adquiriente VARCHAR,
    fecha_recepcion DATE
);
``` 
2. cargamos cada archico a su tabla correspondiente. 


## Ahora sí, es momento de analizar nuestro estudio de caso

Así que...

Tiendo encuenta lo descrito por el enunciado:
    "Una transacción regular se evidencia en la base de datos como un PAGO; se debe tener
     en cuenta que un mismo ID puede también tomar estado de Cancelación, Chargeback u Otros casos."
  
 Luego de revisar el dataset entregado procedimos a: 
 
-Crear un id que nos permita identificar cada transacción en cada base da
 datos (CLAP Y BANSUR) ya que en los datasets no viene dicho id, para lograrlo podemos usar el
 número de la tarjeta, el código de autorización, el monto y el id del adquiriente como criterios
 de unicidad, esto permitirá identificar cada transacción agrupando por estos campos.

``` sql
WITH transacciones AS (
    SELECT tarjeta, codigo_autorizacion, abs(monto) AS monto_abs, id_adquiriente
    FROM bansur
    GROUP BY tarjeta, codigo_autorizacion, abs(monto), id_adquiriente
    ORDER BY tarjeta
)
SELECT row_number() over (), *
FROM transacciones
;
``` 
-- Agregamos una columna para asignar el identificador de la transacción (id)
``` sql
ALTER TABLE bansur
ADD COLUMN id numeric;
```
-- Seguidamente, establecemos el valor de los ids usando el criterio de unicidad antes expuesto
``` sql
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
 ```

Ahora bien, Simetrik considera una partida como conciliable toda aquella transacción cuyo último estado en la base de datos ordenada por fecha y hora  sea PAGADA.
De esta manera, procedemos a identificar la fecha mas reciente de una transaccion y su estado como pagada
``` sql
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
```
Ahora, obtenemos las Partidas conciliables del cliente CLAP.
Para esto debemos asignarle un identificador que coincida con los datos en BANSUR
``` sql
ALTER TABLE clap
ADD COLUMN id numeric;
```

  Con la siguiente consulta podemos verificar si existen transacciones que les falte asignarle el id

``` sql
SELECT COUNT(*)
FROM clap
WHERE id is null
        AND inicio06_tarjeta IS NOT NULL
        AND final4_tarjeta IS NOT NULL
        AND codigo_autorizacion IS NOT NULL
        AND abs(monto) IS NOT NULL
        AND id_banco IS NOT NULL;
  ```
- Despues de ejecutar la consulta anterior, el resultado nos dice que hay transacciones (54491) por asignar un id
  ya que no cruzaron con las de banzur pero se puede identificar usando el criterio de unicidad antes mencionado, es
  decir, las columnas tarjeta, codigo de autorizacion, monto y banco, para asignar estos ids usamos la siguiente consulta
 ``` sql 
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
     ```
- Creamos una vista para calcular la data conciliable con los criterios descritos por Simetrik 
``` sql 
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
 ```

Ahora que ya tenemos las partidas conciliables de cada base de datos,
realizamos el cruce entre las dos entidades para realizar la conciliación
``` sql 
CREATE OR REPLACE VIEW clap_bansur_conciliacion AS (
    SELECT c.id,
           c.tarjeta,
           c.tipo_trx,
           c.monto AS monto_clap,
           b.monto AS monto_bansur,
           c.fecha_transaccion,
           c.codigo_autorizacion AS codigo_clap,
           b.codigo_autorizacion AS codigo_bansur,
           c.id_adquiriente AS id_banco_clap,
           b.id_adquiriente AS id_adquiriente_bansur,
           c.fecha_recepcion AS fecha_recepcion_clap,
           b.fecha_recepcion AS fecha_recepcion_bansur
    FROM clap_conciliable AS c
    INNER JOIN bansur_conciliable b on
            c.id=b.id
            AND c.tarjeta = b.tarjeta
            AND (b.monto-c.monto) BETWEEN -0.99 AND 0.99
            AND c.fecha_transaccion = b.fecha_transaccion
);
```
Una vez realizado el cruce, podemos obtener la respuesta a ¿ Cual fue el porcentaje de cruce (conciliación) alcanzado?
``` sql 
WITH total_transacciones_conciliables AS (
    SELECT id FROM bansur_conciliable
    UNION
    SELECT id FROM clap_conciliable
    ORDER BY id
    )
SELECT
    round(
        100.0*(count(*))/(SELECT count(distinct id) FROM total_transacciones_conciliables),
        2
    ) AS porcentaje_cruce_conciliaciones
FROM clap_bansur_conciliacion;
```
-- porcentaje no conciliado


--El porcentaje de cruce alcanzado es de 52.57%
