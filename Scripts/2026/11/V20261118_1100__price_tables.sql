-- ============================================================================
-- Tabelas de preco particulares (alem da tabela de cada convenio, que ja
-- existe em od.health_plan_price): a clinica cria quantas quiser (ex.:
-- "Particular", "Instalacao aparelho Pinhais", "Parceria empresa X") com o
-- preco de cada procedimento. O orcamento escolhe a tabela; o preco de um
-- item com procedimento vem dela (sem preco na tabela = valor cobrado hoje).
--
--   od.price_table       tabela de preco da filial (uma pode ser a padrao)
--   od.price_table_item  preco do procedimento na tabela
--   od.budget            + nr_price_table
--
-- Leitura por RLS; escrita por ad.price_table_save (tela PRICING) e
-- ad.budget_save (BUDGETS).
-- ============================================================================

create table od.price_table (
  nr_company      bigint         not null,
  nr_branch       bigint         not null,
  nr_price_table  bigint         not null,
  vc_name         varchar(60)    not null,
  id_default      boolean        not null default false,
  vc_notes        varchar(500),
  it_status       smallint       not null default 1,
  nr_operator     bigint,
  dh_created      timestamptz    not null default now(),
  dh_updated      timestamptz    not null default now(),
  constraint price_table_pk primary key (nr_company, nr_branch, nr_price_table),
  constraint price_table_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint price_table_name_check check (length(trim(vc_name)) > 0),
  constraint price_table_status_check check (it_status in (1, 90)),
  constraint price_table_default_check check (not id_default or it_status = 1)
);
create unique index price_table_name_uk on od.price_table (nr_company, nr_branch, lower(vc_name));
create unique index price_table_default_uk on od.price_table (nr_company, nr_branch) where id_default;
alter table od.price_table enable row level security;

create table od.price_table_item (
  nr_company      bigint         not null,
  nr_branch       bigint         not null,
  nr_price_table  bigint         not null,
  nr_procedure    bigint         not null,
  vl_price        numeric(12,2)  not null,
  nr_operator     bigint,
  dh_created      timestamptz    not null default now(),
  dh_updated      timestamptz    not null default now(),
  constraint price_table_item_pk primary key (nr_company, nr_branch, nr_price_table, nr_procedure),
  constraint price_table_item_table_fk foreign key (nr_company, nr_branch, nr_price_table)
    references od.price_table (nr_company, nr_branch, nr_price_table) on delete cascade,
  constraint price_table_item_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint price_table_item_price_check check (vl_price >= 0)
);
alter table od.price_table_item enable row level security;

alter table od.budget add column nr_price_table bigint;
alter table od.budget add constraint budget_price_table_fk foreign key (nr_company, nr_branch, nr_price_table)
  references od.price_table (nr_company, nr_branch, nr_price_table);
