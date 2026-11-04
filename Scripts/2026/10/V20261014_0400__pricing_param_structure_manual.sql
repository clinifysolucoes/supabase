-- ============================================================================
-- Precificacao: custo da estrutura por hora informado manualmente.
--
-- A planilha original calculava R$ 30,36/h e o dentista digitava R$ 30 por
-- cima. Mesmo recurso aqui: od.pricing_param.vl_structure_hour_manual, quando
-- preenchido, substitui o valor calculado a partir das despesas (custo mensal
-- / horas produtivas). Nulo = usa o calculo. od.fn_pricing_context devolve os
-- dois (vl_structure_hour efetivo e vl_structure_hour_calc) e
-- ad.pricing_param_save aceita a chave em params (null limpa).
-- ============================================================================

alter table od.pricing_param
  add column vl_structure_hour_manual numeric(12,2);

alter table od.pricing_param
  add constraint pricing_param_vl_structure_manual_check
  check (vl_structure_hour_manual is null or vl_structure_hour_manual >= 0);
