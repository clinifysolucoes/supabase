-- ============================================================================
-- Schema OD (Odontologia): primeiro modulo de negocio - PRECIFICACAO.
--
-- Toda tabela de negocio tem (nr_company, nr_branch) e RLS de leitura por
-- private.fn_my_branches() (Procedures/BOD/rls_od_policies.pgs). Escrita so
-- pelas RPCs SECURITY DEFINER do schema od, que checam a permissao do usuario
-- na tela PRICING (ad.fn_screen_permission: ler / criar / alterar).
--
-- Modelo (consolidado das tres planilhas de precificacao da clinica):
--   od.pricing_param       parametros da filial: estrutura (salas, horas por
--                          semana, semanas por mes, ocupacao da agenda), hora
--                          clinica do profissional, taxa de cartao, comissao,
--                          regime de imposto de renda (PF / PJ) e lucro desejado
--   od.clinic_expense      despesas da clinica (fixas, variaveis, eventuais
--                          anuais, publicidade) -> custo mensal -> custo da
--                          estrutura por hora produtiva
--   od.pricing_fee         taxas adicionais sobre o preco (ISS, inadimplencia,
--                          antecipacao de recebiveis...) que a clinica liga/desliga
--   od.material            catalogo de materiais: preco da embalagem, rendimento
--                          e perda -> custo por unidade de uso (manual ou pesquisa
--                          de mercado pela Edge Function material-price-lookup)
--   od.procedure           procedimentos: tempo, laboratorio, outros materiais,
--                          valor atual cobrado, comissao e lucro proprios (opcionais)
--   od.procedure_material  materiais x quantidade usada em cada procedimento
--
-- Formula (od.fn_pricing_calc):
--   custo direto = materiais + laboratorio + tempo x custo da estrutura/h
--                  + tempo x hora clinica do profissional
--   preco        = custo direto / (1 - cartao - comissao - taxas - IR - lucro)   [PJ: IR sobre o faturamento]
--                = (1 - IR) x custo direto / ((1 - IR) x (1 - cartao - comissao - taxas) - lucro)   [PF: IR sobre o lucro]
--   preco minimo = mesma formula com lucro zero.
-- Percentuais (pc_*) sao guardados em pontos percentuais (4.00 = 4%).
-- ============================================================================

create schema if not exists od;

revoke all on schema od from public;
grant usage on schema od to authenticated, service_role;

-- Mesmos privilegios default do schema ad: authenticated le (RLS), nunca escreve.
alter default privileges in schema od grant select on tables to authenticated;
alter default privileges in schema od grant all on tables to service_role;
alter default privileges in schema od grant all on sequences to service_role;
alter default privileges in schema od revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- od.pricing_param - uma linha por filial (criada no primeiro salvamento)
-- ---------------------------------------------------------------------------
create table od.pricing_param (
  nr_company            bigint         not null,
  nr_branch             bigint         not null,
  qt_rooms              smallint       not null default 1,
  qt_hours_week         numeric(6,2)   not null default 40,
  qt_weeks_month        numeric(4,2)   not null default 4.33,
  pc_occupancy          numeric(5,2)   not null default 70,
  vl_professional_hour  numeric(12,2)  not null default 0,
  pc_card               numeric(5,2)   not null default 4,
  pc_commission         numeric(5,2)   not null default 0,
  it_tax_regime         smallint       not null default 1,
  pc_tax_pf             numeric(5,2)   not null default 27.5,
  pc_tax_pj             numeric(5,2)   not null default 11.33,
  pc_profit             numeric(5,2)   not null default 30,
  nr_operator           bigint,
  dh_created            timestamptz    not null default now(),
  dh_updated            timestamptz    not null default now(),
  constraint pricing_param_pk primary key (nr_company, nr_branch),
  constraint pricing_param_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint pricing_param_qt_rooms_check       check (qt_rooms >= 1),
  constraint pricing_param_qt_hours_week_check  check (qt_hours_week > 0 and qt_hours_week <= 168),
  constraint pricing_param_qt_weeks_month_check check (qt_weeks_month > 0 and qt_weeks_month <= 5),
  constraint pricing_param_pc_occupancy_check   check (pc_occupancy > 0 and pc_occupancy <= 100),
  constraint pricing_param_vl_hour_check        check (vl_professional_hour >= 0),
  constraint pricing_param_pc_check             check (pc_card between 0 and 100 and pc_commission between 0 and 100
                                                   and pc_tax_pf between 0 and 100 and pc_tax_pj between 0 and 100
                                                   and pc_profit between 0 and 100),
  constraint pricing_param_it_tax_regime_check  check (it_tax_regime in (1, 2))
);

alter table od.pricing_param enable row level security;

-- ---------------------------------------------------------------------------
-- od.clinic_expense - despesas que formam o custo mensal da clinica
-- ---------------------------------------------------------------------------
create table od.clinic_expense (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_expense    bigint         not null,
  vc_name       varchar(60)    not null,
  it_type       smallint       not null default 1,
  vl_amount     numeric(12,2)  not null default 0,
  it_status     smallint       not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint clinic_expense_pk primary key (nr_company, nr_branch, nr_expense),
  constraint clinic_expense_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint clinic_expense_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint clinic_expense_it_type_check   check (it_type in (1, 2, 3, 4)),
  constraint clinic_expense_vl_amount_check check (vl_amount >= 0),
  constraint clinic_expense_it_status_check check (it_status in (1, 90))
);

alter table od.clinic_expense enable row level security;

-- ---------------------------------------------------------------------------
-- od.pricing_fee - taxas adicionais sobre o preco (ligaveis por filial)
-- ---------------------------------------------------------------------------
create table od.pricing_fee (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_fee        bigint         not null,
  vc_name       varchar(60)    not null,
  vc_hint       varchar(200),
  pc_rate       numeric(5,2)   not null default 0,
  id_active     boolean        not null default false,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint pricing_fee_pk primary key (nr_company, nr_branch, nr_fee),
  constraint pricing_fee_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint pricing_fee_vc_name_check check (length(trim(vc_name)) > 0),
  constraint pricing_fee_pc_rate_check check (pc_rate between 0 and 100)
);

alter table od.pricing_fee enable row level security;

-- ---------------------------------------------------------------------------
-- od.material - catalogo de materiais da filial
-- ---------------------------------------------------------------------------
create table od.material (
  nr_company        bigint         not null,
  nr_branch         bigint         not null,
  nr_material       bigint         not null,
  vc_name           varchar(80)    not null,
  vc_package        varchar(40),
  vl_package_price  numeric(12,2)  not null default 0,
  qt_yield          numeric(10,3)  not null default 1,
  vc_unit           varchar(20),
  pc_waste          numeric(5,2)   not null default 0,
  it_price_source   smallint       not null default 1,
  vc_price_source   varchar(200),
  dh_price_updated  timestamptz,
  it_status         smallint       not null default 1,
  nr_operator       bigint,
  dh_created        timestamptz    not null default now(),
  dh_updated        timestamptz    not null default now(),
  constraint material_pk primary key (nr_company, nr_branch, nr_material),
  constraint material_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint material_vc_name_check          check (length(trim(vc_name)) > 0),
  constraint material_vl_package_price_check check (vl_package_price >= 0),
  constraint material_qt_yield_check         check (qt_yield > 0),
  constraint material_pc_waste_check         check (pc_waste >= 0 and pc_waste < 100),
  constraint material_it_price_source_check  check (it_price_source in (1, 2)),
  constraint material_it_status_check        check (it_status in (1, 90))
);

create unique index material_vc_name_uk on od.material (nr_company, nr_branch, lower(vc_name));

alter table od.material enable row level security;

-- ---------------------------------------------------------------------------
-- od.procedure - procedimentos precificados
-- ---------------------------------------------------------------------------
create table od.procedure (
  nr_company          bigint         not null,
  nr_branch           bigint         not null,
  nr_procedure        bigint         not null,
  vc_code             varchar(10),
  vc_name             varchar(80)    not null,
  vc_category         varchar(40),
  qt_minutes          numeric(7,2)   not null default 0,
  vl_lab_cost         numeric(12,2)  not null default 0,
  vl_material_other   numeric(12,2)  not null default 0,
  vl_current_price    numeric(12,2),
  pc_commission       numeric(5,2),
  pc_profit           numeric(5,2),
  it_status           smallint       not null default 1,
  nr_operator         bigint,
  dh_created          timestamptz    not null default now(),
  dh_updated          timestamptz    not null default now(),
  constraint procedure_pk primary key (nr_company, nr_branch, nr_procedure),
  constraint procedure_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint procedure_vc_name_check           check (length(trim(vc_name)) > 0),
  constraint procedure_qt_minutes_check        check (qt_minutes >= 0),
  constraint procedure_vl_lab_cost_check       check (vl_lab_cost >= 0),
  constraint procedure_vl_material_other_check check (vl_material_other >= 0),
  constraint procedure_vl_current_price_check  check (vl_current_price is null or vl_current_price >= 0),
  constraint procedure_pc_commission_check     check (pc_commission is null or pc_commission between 0 and 100),
  constraint procedure_pc_profit_check         check (pc_profit is null or pc_profit between 0 and 100),
  constraint procedure_it_status_check         check (it_status in (1, 90))
);

create unique index procedure_vc_name_uk on od.procedure (nr_company, nr_branch, lower(vc_name));
create unique index procedure_vc_code_uk on od.procedure (nr_company, nr_branch, lower(vc_code)) where vc_code is not null;

alter table od.procedure enable row level security;

-- ---------------------------------------------------------------------------
-- od.procedure_material - materiais e quantidades de cada procedimento
-- ---------------------------------------------------------------------------
create table od.procedure_material (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_procedure  bigint         not null,
  nr_material   bigint         not null,
  qt_used       numeric(10,3)  not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint procedure_material_pk primary key (nr_company, nr_branch, nr_procedure, nr_material),
  constraint procedure_material_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure) on delete cascade,
  constraint procedure_material_material_fk foreign key (nr_company, nr_branch, nr_material)
    references od.material (nr_company, nr_branch, nr_material),
  constraint procedure_material_qt_used_check check (qt_used > 0)
);

create index procedure_material_nr_material_idx on od.procedure_material (nr_company, nr_branch, nr_material);

alter table od.procedure_material enable row level security;

-- ---------------------------------------------------------------------------
-- Tela PRICING no catalogo global (uuid fixo, igual em todos os ambientes).
-- ---------------------------------------------------------------------------
insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000005', 'PRICING', 'Precificação', 'Gestão', 15);
