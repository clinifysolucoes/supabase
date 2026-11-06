-- ============================================================================
-- Configuracoes: lacunas em relacao ao Clinicorp.
--
--   od.branch_setting  + id_budget_request_approval      desconto acima do maximo pode ser
--                                                          enviado para aprovacao (senao bloqueia)
--                      + id_budget_admin_below_min       administrador pode aprovar valor
--                                                          abaixo do preco minimo da precificacao
--                      + id_budget_reduction_as_discount reduzir o valor do procedimento conta
--                                                          como desconto
--                      + it_open_rule                    paciente com conta a receber em aberto
--                                                          (nao vencida) ao agendar: 1 nao
--                                                          bloquear, 2 avisar, 3 administrador
--                                                          libera, 4 bloquear
--                      + it_late_edit                    multa e juros na baixa: 0 editaveis,
--                                                          1 so o administrador reduz,
--                                                          2 nao podem ser reduzidos
--   od.budget          + id_below_min    algum item abaixo do preco minimo
--   od.fin_category    + it_dre_group    grupo da categoria no DRE (nulo = automatico)
-- ============================================================================

alter table od.branch_setting add column id_budget_request_approval boolean not null default true;
alter table od.branch_setting add column id_budget_admin_below_min boolean not null default true;
alter table od.branch_setting add column id_budget_reduction_as_discount boolean not null default false;
alter table od.branch_setting add column it_open_rule smallint not null default 1;
alter table od.branch_setting add column it_late_edit smallint not null default 0;
alter table od.branch_setting add constraint branch_setting_open_rule_check check (it_open_rule in (1, 2, 3, 4));
alter table od.branch_setting add constraint branch_setting_late_edit_check check (it_late_edit in (0, 1, 2));

alter table od.budget add column id_below_min boolean not null default false;

alter table od.fin_category add column it_dre_group smallint;
alter table od.fin_category add constraint fin_category_dre_group_check
  check (it_dre_group is null or it_dre_group between 1 and 8);
