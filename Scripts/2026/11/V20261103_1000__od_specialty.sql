-- ============================================================================
-- Precificacao (schema od): especialidades.
--
-- A especialidade (Clinica Geral, Implante, Ortodontia, HOF, Endodontia,
-- Protese...) agrupa os procedimentos e tem lucro desejado proprio, como nas
-- abas "Valor <especialidade>" da planilha da clinica. Ordem do lucro usado no
-- preco: procedimento (pc_profit) > especialidade (pc_profit) > filial
-- (pricing_param.pc_profit).
--
-- od.procedure.vc_category (texto livre) vira od.procedure.nr_specialty: as
-- categorias existentes sao migradas para od.specialty (uma por nome distinto
-- na filial) antes de a coluna ser removida.
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.specialty_save e ad.procedure_save (tela PRICING).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.specialty - especialidades da filial (nr_specialty sequencial por filial)
-- ---------------------------------------------------------------------------
create table od.specialty (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_specialty  bigint         not null,
  vc_name       varchar(40)    not null,
  pc_profit     numeric(5,2),
  it_status     smallint       not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint specialty_pk primary key (nr_company, nr_branch, nr_specialty),
  constraint specialty_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint specialty_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint specialty_pc_profit_check check (pc_profit is null or pc_profit between 0 and 100),
  constraint specialty_it_status_check check (it_status in (1, 90))
);

create unique index specialty_vc_name_uk on od.specialty (nr_company, nr_branch, lower(vc_name));

alter table od.specialty enable row level security;

-- ---------------------------------------------------------------------------
-- od.procedure.nr_specialty
-- ---------------------------------------------------------------------------
alter table od.procedure add column nr_specialty bigint;

alter table od.procedure add constraint procedure_specialty_fk foreign key (nr_company, nr_branch, nr_specialty)
  references od.specialty (nr_company, nr_branch, nr_specialty);

create index procedure_nr_specialty_idx on od.procedure (nr_company, nr_branch, nr_specialty);

-- categorias de texto -> especialidades (nome distinto, sem diferenciar maiusculas)
insert into od.specialty (nr_company, nr_branch, nr_specialty, vc_name)
select c.nr_company, c.nr_branch,
       row_number() over (partition by c.nr_company, c.nr_branch order by c.vc_name),
       c.vc_name
  from (select distinct on (p.nr_company, p.nr_branch, lower(trim(p.vc_category)))
               p.nr_company, p.nr_branch, trim(p.vc_category) as vc_name
          from od.procedure p
         where nullif(trim(p.vc_category), '') is not null
         order by p.nr_company, p.nr_branch, lower(trim(p.vc_category)), trim(p.vc_category)) c;

update od.procedure p
   set nr_specialty = s.nr_specialty
  from od.specialty s
 where s.nr_company = p.nr_company
   and s.nr_branch  = p.nr_branch
   and lower(s.vc_name) = lower(trim(p.vc_category));

alter table od.procedure drop column vc_category;
