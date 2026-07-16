-- ============================================================================
--  AJUSTES PARA LA FASE 4 (logica de negocio)
--  Cambios ADITIVOS y no destructivos. Se ejecuta despues de 01 y 02
--  (initdb corre los *.sql en orden alfabetico) y ANTES del seed (04).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. pago.id_metodo_pago pasa a ser NULLABLE
-- ----------------------------------------------------------------------------
-- El contrato (API_REST.md 5.4) dice que id_metodo_pago es null mientras el
-- pago sigue pendiente: al crear la intencion todavia no se sabe con que va a
-- pagar el usuario; eso solo se conoce cuando la pasarela confirma.
-- El esquema original lo declaro NOT NULL, lo que obligaria a inventar un
-- metodo falso al crear la intencion y luego corregirlo.
--
-- Se descarto la alternativa de anadir un metodo "pendiente" al catalogo:
-- los IDs de metodo_pago estan hardcodeados como enum en la app Flutter y en
-- app/core/enums.py, y contaminarlos romperia ambos lados.
ALTER TABLE pago
  ALTER COLUMN id_metodo_pago DROP NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. Secuencia para codigo_reserva
-- ----------------------------------------------------------------------------
-- Genera el correlativo de "RSV-000123". Se usa una secuencia y no el
-- id_reserva porque codigo_reserva es NOT NULL UNIQUE: habria que insertar un
-- valor provisional y actualizarlo despues de conocer el id.
--
-- Las secuencias son atomicas y NO se revierten en un rollback: si una reserva
-- falla por el EXCLUDE anti-overbooking se salta un numero. Es el
-- comportamiento correcto (nunca dos reservas con el mismo codigo).
CREATE SEQUENCE IF NOT EXISTS seq_codigo_reserva START 1;
