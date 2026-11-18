-- ============================================================================
-- Bloqueios do paciente em tres momentos, como no Clinicorp:
--   agenda     ao agendar (ja existiam it_debt_rule e it_open_rule)
--   check-in   ao marcar a chegada (consulta vai para Em espera)
--   tratamento ao iniciar o atendimento (Em atendimento) e ao registrar a
--              evolucao clinica
-- e tres pendencias: conta vencida (inadimplencia), conta em aberto e
-- contrato sem assinatura (documento do tipo Contrato ativo sem assinatura do
-- paciente ou do responsavel legal).
-- Regra (mesmos valores de it_debt_rule): 1 nao bloquear, 2 avisar,
-- 3 so o administrador da empresa libera, 4 bloquear.
--
--   od.branch_setting  + it_contract_rule (agenda)
--                      + it_checkin_debt_rule, it_checkin_open_rule, it_checkin_contract_rule
--                      + it_treat_debt_rule, it_treat_open_rule, it_treat_contract_rule
-- ============================================================================

alter table od.branch_setting add column it_contract_rule smallint not null default 1;
alter table od.branch_setting add column it_checkin_debt_rule smallint not null default 1;
alter table od.branch_setting add column it_checkin_open_rule smallint not null default 1;
alter table od.branch_setting add column it_checkin_contract_rule smallint not null default 1;
alter table od.branch_setting add column it_treat_debt_rule smallint not null default 1;
alter table od.branch_setting add column it_treat_open_rule smallint not null default 1;
alter table od.branch_setting add column it_treat_contract_rule smallint not null default 1;
alter table od.branch_setting add constraint branch_setting_block_rules_check check (
  it_contract_rule between 1 and 4
  and it_checkin_debt_rule between 1 and 4 and it_checkin_open_rule between 1 and 4
  and it_checkin_contract_rule between 1 and 4
  and it_treat_debt_rule between 1 and 4 and it_treat_open_rule between 1 and 4
  and it_treat_contract_rule between 1 and 4);
