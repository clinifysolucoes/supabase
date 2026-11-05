-- ============================================================================
-- Configuracoes da clinica, parte A: tela Configuracoes, dados da clinica,
-- preferencias da agenda e do cadastro de pacientes, horario de funcionamento.
--
--   ad.screen            + SETTINGS (Configuracoes, uuid fixo ...0009)
--   ad.branch            + telefone adicional, responsavel tecnico (nome, CRO,
--                          UF do CRO) e cidade do foro (nulo = a da clinica)
--   od.branch_setting    uma linha por filial (sem linha = padroes):
--                          agenda: intervalo de visualizacao, quantas consultas
--                          do mesmo profissional no mesmo horario, se pode
--                          agendar fora do horario de atendimento;
--                          pacientes: numero de prontuario automatico (e o
--                          proximo numero), CPF e celular obrigatorios
--   od.branch_hour       horario de funcionamento da clinica por dia da semana
--                          (mais de um intervalo por dia)
--
-- Leitura por RLS (private.fn_my_branches); escrita so pela RPC
-- ad.settings_save (tela SETTINGS) e, nos dados da clinica, ad.branch_update.
-- ============================================================================

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000009', 'SETTINGS', 'Configurações', 'Administração', 25);

alter table ad.branch add column vc_phone_extra varchar(11);
alter table ad.branch add column vc_technical_name varchar(120);
alter table ad.branch add column vc_technical_cro varchar(20);
alter table ad.branch add column vc_technical_cro_state varchar(2);
alter table ad.branch add column vc_forum_city varchar(60);
alter table ad.branch add constraint branch_phone_extra_check
  check (vc_phone_extra is null or vc_phone_extra ~ '^[0-9]{10,11}$');
alter table ad.branch add constraint branch_cro_state_check
  check (vc_technical_cro_state is null or vc_technical_cro_state ~ '^[A-Z]{2}$');

-- ---------------------------------------------------------------------------
-- od.branch_setting
-- ---------------------------------------------------------------------------
create table od.branch_setting (
  nr_company              bigint       not null,
  nr_branch               bigint       not null,
  qt_slot_minutes         smallint     not null default 15,
  qt_max_parallel         smallint     not null default 1,
  id_allow_outside_hours  boolean      not null default true,
  id_auto_record_number   boolean      not null default false,
  nr_next_record          bigint       not null default 1,
  id_require_cpf          boolean      not null default false,
  id_require_mobile       boolean      not null default false,
  nr_operator             bigint,
  dh_created              timestamptz  not null default now(),
  dh_updated              timestamptz  not null default now(),
  constraint branch_setting_pk primary key (nr_company, nr_branch),
  constraint branch_setting_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint branch_setting_slot_check     check (qt_slot_minutes in (5, 15, 20, 30)),
  constraint branch_setting_parallel_check check (qt_max_parallel between 1 and 20),
  constraint branch_setting_record_check   check (nr_next_record >= 1)
);

alter table od.branch_setting enable row level security;

-- ---------------------------------------------------------------------------
-- od.branch_hour
-- ---------------------------------------------------------------------------
create table od.branch_hour (
  nr_company       bigint       not null,
  nr_branch        bigint       not null,
  nr_hour          bigint       not null,
  it_weekday       smallint     not null,
  qt_minute_start  smallint     not null,
  qt_minute_end    smallint     not null,
  nr_operator      bigint,
  dh_created       timestamptz  not null default now(),
  dh_updated       timestamptz  not null default now(),
  constraint branch_hour_pk primary key (nr_company, nr_branch, nr_hour),
  constraint branch_hour_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint branch_hour_weekday_check check (it_weekday between 0 and 6),
  constraint branch_hour_period_check  check (qt_minute_start between 0 and 1439
                                              and qt_minute_end between 1 and 1440
                                              and qt_minute_end > qt_minute_start)
);

create index branch_hour_day_idx on od.branch_hour (nr_company, nr_branch, it_weekday);

alter table od.branch_hour enable row level security;
