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
