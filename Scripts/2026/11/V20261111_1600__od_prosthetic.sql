-- ============================================================================
-- Controle Protetico: trabalhos enviados ao laboratorio (coroas, proteses,
-- placas...) com etapa, prazos e custo; cada mudanca de etapa fica no
-- historico. Ao receber o trabalho do laboratorio (fornecedor do financeiro),
-- o custo vira uma conta a pagar.
--
--   od.prosthetic_work       trabalho protetico do paciente
--   od.prosthetic_work_step  historico das etapas (envio, prova, retorno...)
--
-- Tela nova PROSTHETIC (Clinica).
-- ============================================================================

create table od.prosthetic_work (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_work          bigint         not null,
  nr_patient       bigint         not null,
  nr_professional  bigint,
  nr_supplier      bigint,
  vc_lab           varchar(120),
  nr_budget        bigint,
  nr_item          smallint,
  vc_description   varchar(120)   not null,
  vc_tooth         varchar(40),
  vc_shade         varchar(40),
  vc_notes         varchar(1000),
  it_stage         smallint       not null default 1,
  dt_sent          date,
  dt_expected      date,
  dt_received      date,
  dt_installed     date,
  vl_cost          numeric(12,2),
  nr_entry         bigint,
  nr_user_created  bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint prosthetic_work_pk primary key (nr_company, nr_branch, nr_work),
  constraint prosthetic_work_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint prosthetic_work_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint prosthetic_work_supplier_fk foreign key (nr_company, nr_branch, nr_supplier)
    references od.fin_supplier (nr_company, nr_branch, nr_supplier),
  constraint prosthetic_work_item_fk foreign key (nr_company, nr_branch, nr_budget, nr_item)
    references od.budget_item (nr_company, nr_branch, nr_budget, nr_item),
  constraint prosthetic_work_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint prosthetic_work_user_fk foreign key (nr_user_created) references ad.app_user (nr_user),
  constraint prosthetic_work_stage_check check (it_stage in (1, 2, 3, 4, 5, 90)),
  constraint prosthetic_work_description_check check (length(trim(vc_description)) > 0),
  constraint prosthetic_work_cost_check check (vl_cost is null or vl_cost >= 0),
  constraint prosthetic_work_item_check check ((nr_budget is null) = (nr_item is null))
);
create index prosthetic_work_patient_idx on od.prosthetic_work (nr_company, nr_branch, nr_patient);
create index prosthetic_work_stage_idx on od.prosthetic_work (nr_company, nr_branch, it_stage, dt_expected);
alter table od.prosthetic_work enable row level security;

create table od.prosthetic_work_step (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_work          bigint         not null,
  nr_step          smallint       not null,
  it_stage         smallint       not null,
  dt_step          date           not null,
  vc_notes         varchar(500),
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint prosthetic_work_step_pk primary key (nr_company, nr_branch, nr_work, nr_step),
  constraint prosthetic_work_step_work_fk foreign key (nr_company, nr_branch, nr_work)
    references od.prosthetic_work (nr_company, nr_branch, nr_work),
  constraint prosthetic_work_step_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint prosthetic_work_step_stage_check check (it_stage in (1, 2, 3, 4, 5, 90))
);
alter table od.prosthetic_work_step enable row level security;


insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000012', 'PROSTHETIC', 'Controle Protético', 'Clínica', 17);
