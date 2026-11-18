-- ============================================================================
-- Prontuario: sessoes, retorno e tempo de execucao por procedimento (como em
-- Configuracoes > Prontuario > Geral do Clinicorp).
--
--   od.branch_setting     + id_record_sessions  item do orcamento em varias sessoes
--                         + id_record_return    retorno automatico do procedimento
--                         + id_record_time      registrar o tempo de cada procedimento
--   od.procedure          + qt_sessions         sessoes previstas (padrao 1)
--                         + qt_return_days      retorno em N dias depois de concluir (opcional)
--   od.budget_item        + qt_sessions         sessoes do item (copiado do procedimento)
--                         + qt_sessions_done    sessoes ja realizadas na evolucao
--   od.clinical_evolution + nr_session          numero da sessao do item
--                         + qt_minutes          tempo de execucao registrado
-- ============================================================================

alter table od.branch_setting add column id_record_sessions boolean not null default false;
alter table od.branch_setting add column id_record_return boolean not null default false;
alter table od.branch_setting add column id_record_time boolean not null default false;

alter table od.procedure add column qt_sessions smallint not null default 1;
alter table od.procedure add column qt_return_days smallint;
alter table od.procedure add constraint procedure_sessions_check
  check (qt_sessions between 1 and 60 and (qt_return_days is null or qt_return_days between 1 and 730));

alter table od.budget_item add column qt_sessions smallint not null default 1;
alter table od.budget_item add column qt_sessions_done smallint not null default 0;
alter table od.budget_item add constraint budget_item_sessions_check
  check (qt_sessions between 1 and 60 and qt_sessions_done between 0 and qt_sessions);

alter table od.clinical_evolution add column nr_session smallint;
alter table od.clinical_evolution add column qt_minutes smallint;
alter table od.clinical_evolution add constraint clinical_evolution_session_check
  check ((nr_session is null or nr_session between 1 and 60) and (qt_minutes is null or qt_minutes between 1 and 600));
