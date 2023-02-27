

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


