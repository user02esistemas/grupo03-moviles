-- ============================================================================
--  MERCADO PAGO (Checkout Pro - Opcion A)
--  Cambio ADITIVO y no destructivo sobre la tabla pago.
--  Se ejecuta despues de 01_schema.sql (orden alfabetico en initdb).
-- ============================================================================

-- Referencia externa del pago en Mercado Pago.
-- Guardamos aqui el payment_id / preference_id de MP para:
--   1) correlacionar el webhook con la fila local sin ambiguedad, y
--   2) idempotencia: no procesar dos veces la misma notificacion.
-- Es NULLABLE porque al crear la intencion aun no existe el pago en MP.
ALTER TABLE pago
  ADD COLUMN IF NOT EXISTS referencia_externa VARCHAR(255);

-- Busqueda rapida por referencia al recibir el webhook.
CREATE INDEX IF NOT EXISTS idx_pago_referencia_externa
  ON pago(referencia_externa)
  WHERE referencia_externa IS NOT NULL;
