-- ============================================================================
-- Orcamentos (planos de tratamento) dos pacientes.
--
--   ad.screen          + BUDGETS (Orcamentos, uuid fixo ...0010)
--   od.budget          orcamento do paciente: numero sequencial por filial,
--                        profissional, validade, total bruto, desconto, total,
--                        condicao de pagamento e situacao (1 em aberto,
--                        2 aguardando aprovacao do desconto, 3 aprovado pelo
--                        paciente, 4 recusado, 90 cancelado). Desconto acima
--                        do maximo da filial precisa do administrador.
--   od.budget_item     procedimentos do orcamento (dente/regiao, quantidade,
--                        valor unitario e total)
--   od.fin_entry       + nr_budget  orcamento que gerou a conta a receber
--   od.branch_setting  + pc_budget_max_discount  desconto maximo sem aprovacao (%)
--                      + qt_budget_valid_days    validade padrao (dias)
--
-- Leitura por RLS (private.fn_my_branches); escrita so pelas RPCs
-- ad.budget_save / ad.budget_status (tela BUDGETS).
-- ============================================================================

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000010', 'BUDGETS', 'Orçamentos', 'Clínica', 13);

alter table od.branch_setting add column pc_budget_max_discount numeric(5,2) not null default 10;
alter table od.branch_setting add column qt_budget_valid_days smallint not null default 30;
alter table od.branch_setting add constraint branch_setting_budget_check
  check (pc_budget_max_discount between 0 and 100 and qt_budget_valid_days between 1 and 365);

create table od.budget (
  nr_company            bigint         not null,
  nr_branch             bigint         not null,
  nr_budget             bigint         not null,
  nr_patient            bigint         not null,
  nr_professional       bigint,
  vc_title              varchar(80),
  dt_budget             date           not null,
  dt_valid              date           not null,
  vl_gross              numeric(14,2)  not null default 0,
  vl_discount           numeric(14,2)  not null default 0,
  vl_total              numeric(14,2)  not null default 0,
  qt_installments       smallint,
  it_payment_method     smallint,
  vc_notes              varchar(1000),
  it_status             smallint       not null default 1,
  id_discount_approved  boolean        not null default false,
  nr_user_discount      bigint,
  dh_discount           timestamptz,
  dh_accepted           timestamptz,
  nr_user_created       bigint,
  nr_operator           bigint,
  dh_created            timestamptz    not null default now(),
  dh_updated            timestamptz    not null default now(),
  constraint budget_pk primary key (nr_company, nr_branch, nr_budget),
  constraint budget_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint budget_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint budget_user_discount_fk foreign key (nr_user_discount) references ad.app_user (nr_user),
  constraint budget_user_created_fk foreign key (nr_user_created) references ad.app_user (nr_user),
  constraint budget_dates_check        check (dt_valid >= dt_budget),
  constraint budget_values_check       check (vl_gross >= 0 and vl_discount >= 0 and vl_discount <= vl_gross
                                              and vl_total = vl_gross - vl_discount),
  constraint budget_installments_check check (qt_installments is null or qt_installments between 1 and 24),
  constraint budget_method_check       check (it_payment_method is null or it_payment_method in (1, 2, 3, 4, 5, 6, 7, 9)),
  constraint budget_it_status_check    check (it_status in (1, 2, 3, 4, 90))
);

create index budget_patient_idx on od.budget (nr_company, nr_branch, nr_patient);
create index budget_date_idx on od.budget (nr_company, nr_branch, dt_budget);

alter table od.budget enable row level security;

create table od.budget_item (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_budget      bigint         not null,
  nr_item        smallint       not null,
  nr_procedure   bigint,
  vc_description varchar(120)   not null,
  vc_tooth       varchar(40),
  qt_quantity    numeric(7,2)   not null default 1,
  vl_unit        numeric(12,2)  not null default 0,
  vl_total       numeric(14,2)  not null default 0,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint budget_item_pk primary key (nr_company, nr_branch, nr_budget, nr_item),
  constraint budget_item_budget_fk foreign key (nr_company, nr_branch, nr_budget)
    references od.budget (nr_company, nr_branch, nr_budget) on delete cascade,
  constraint budget_item_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint budget_item_description_check check (length(trim(vc_description)) > 0),
  constraint budget_item_values_check      check (qt_quantity > 0 and vl_unit >= 0 and vl_total >= 0)
);

alter table od.budget_item enable row level security;

alter table od.fin_entry add column nr_budget bigint;
alter table od.fin_entry add constraint fin_entry_budget_fk foreign key (nr_company, nr_branch, nr_budget)
  references od.budget (nr_company, nr_branch, nr_budget);
create index fin_entry_budget_idx on od.fin_entry (nr_company, nr_branch, nr_budget) where nr_budget is not null;
