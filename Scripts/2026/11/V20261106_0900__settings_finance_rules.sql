-- ============================================================================
-- Configuracoes da clinica, parte B: bloqueio de pacientes com contas
-- vencidas, caixa do dia e formas de pagamento aceitas, multa e juros.
--
--   od.branch_setting  + it_debt_rule       o que fazer ao agendar paciente com
--                                            conta a receber vencida: 1 nao
--                                            bloquear, 2 avisar, 3 so o
--                                            administrador da empresa libera,
--                                            4 bloquear
--                      + qt_debt_days       dias de tolerancia depois do
--                                            vencimento (0..365)
--                      + id_cash_enabled    usa o caixa do dia (abrir/fechar)
--                      + it_payment_methods formas aceitas ao receber
--                                            (it_payment_method da fin_entry)
--                      + pc_late_fee        multa por atraso (% do valor, 0..10)
--                      + pc_late_interest   juros de mora ao mes (% pro rata
--                                            dia, 0..10)
--
-- Leitura por RLS (ja existente); escrita so por ad.settings_save.
-- ============================================================================

alter table od.branch_setting add column it_debt_rule smallint not null default 1;
alter table od.branch_setting add column qt_debt_days smallint not null default 0;
alter table od.branch_setting add column id_cash_enabled boolean not null default true;
alter table od.branch_setting add column it_payment_methods smallint[] not null default '{1,2,3,4,5,6,7,9}';
alter table od.branch_setting add column pc_late_fee numeric(5,2) not null default 0;
alter table od.branch_setting add column pc_late_interest numeric(5,2) not null default 0;

alter table od.branch_setting add constraint branch_setting_debt_rule_check
  check (it_debt_rule in (1, 2, 3, 4));
alter table od.branch_setting add constraint branch_setting_debt_days_check
  check (qt_debt_days between 0 and 365);
alter table od.branch_setting add constraint branch_setting_payment_methods_check
  check (cardinality(it_payment_methods) >= 1 and it_payment_methods <@ '{1,2,3,4,5,6,7,9}'::smallint[]);
alter table od.branch_setting add constraint branch_setting_late_fee_check
  check (pc_late_fee between 0 and 10);
alter table od.branch_setting add constraint branch_setting_late_interest_check
  check (pc_late_interest between 0 and 10);
