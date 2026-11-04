-- ============================================================================
-- As RPCs da precificacao passam a viver no schema ad (o UNICO schema exposto na
-- API). O schema od continua com as tabelas, as policies e os helpers
-- (fn_pricing_calc, fn_pricing_context): o app nunca le od direto, so por RPC.
--
-- Motivo: cada schema novo exigiria mexer em "Exposed schemas" no dashboard de
-- cada projeto Supabase (homologacao e producao) - passo manual que ja deixou a
-- tela sem dados. Com a API toda em ad, nenhum modulo futuro precisa disso.
--
-- As functions od.* abaixo existiram apenas em homologacao (PR 9); em producao
-- nunca foram criadas (drop ... if exists). As versoes em ad sao criadas pelas
-- repeatables Procedures/BAD/{pricing_param_get,pricing_param_save,material_list,
-- material_save,procedure_list,procedure_save}.pgs, que rodam depois desta.
-- ============================================================================

drop function if exists od.pricing_param_get(jsonb);
drop function if exists od.pricing_param_save(jsonb);
drop function if exists od.material_list(jsonb);
drop function if exists od.material_save(jsonb);
drop function if exists od.procedure_list(jsonb);
drop function if exists od.procedure_save(jsonb);
