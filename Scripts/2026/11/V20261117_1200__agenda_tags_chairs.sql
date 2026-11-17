-- ============================================================================
-- Agenda: categorias, marcadores e cadeiras.
--
--   od.appointment_category  categoria do agendamento (Avaliacao, Retorno,
--                            Urgencia...), com cor; a agenda pode colorir os
--                            cartoes pela categoria em vez do profissional
--   od.appointment_marker    marcadores (etiquetas livres, varios por consulta)
--   od.appointment_tag       marcadores de cada agendamento
--   od.chair                 cadeiras (consultorios) da filial; a agenda pode
--                            ser organizada por cadeira em vez de profissional
--   od.appointment           + nr_category, nr_chair
--   od.branch_setting        + id_color_by_category  cor do cartao pela categoria
--                            + it_agenda_mode        1 por profissional, 2 por cadeira
--
-- Leitura por RLS (private.fn_my_branches); escrita so pelas RPCs
-- ad.agenda_catalog_save (tela SETTINGS), ad.appointment_save (AGENDA) e
-- ad.settings_save.
-- ============================================================================

create table od.appointment_category (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_category   bigint         not null,
  vc_name       varchar(40)    not null,
  vc_color      varchar(7)     not null,
  it_status     smallint       not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint appointment_category_pk primary key (nr_company, nr_branch, nr_category),
  constraint appointment_category_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint appointment_category_name_check check (length(trim(vc_name)) > 0),
  constraint appointment_category_color_check check (vc_color ~ '^#[0-9A-F]{6}$'),
  constraint appointment_category_status_check check (it_status in (1, 90))
);
create unique index appointment_category_name_uk on od.appointment_category (nr_company, nr_branch, lower(vc_name));
alter table od.appointment_category enable row level security;

create table od.appointment_marker (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_marker     bigint         not null,
  vc_name       varchar(40)    not null,
  vc_color      varchar(7)     not null,
  it_status     smallint       not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint appointment_marker_pk primary key (nr_company, nr_branch, nr_marker),
  constraint appointment_marker_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint appointment_marker_name_check check (length(trim(vc_name)) > 0),
  constraint appointment_marker_color_check check (vc_color ~ '^#[0-9A-F]{6}$'),
  constraint appointment_marker_status_check check (it_status in (1, 90))
);
create unique index appointment_marker_name_uk on od.appointment_marker (nr_company, nr_branch, lower(vc_name));
alter table od.appointment_marker enable row level security;

create table od.chair (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_chair      bigint         not null,
  vc_name       varchar(40)    not null,
  vc_color      varchar(7)     not null,
  it_status     smallint       not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint chair_pk primary key (nr_company, nr_branch, nr_chair),
  constraint chair_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint chair_name_check check (length(trim(vc_name)) > 0),
  constraint chair_color_check check (vc_color ~ '^#[0-9A-F]{6}$'),
  constraint chair_status_check check (it_status in (1, 90))
);
create unique index chair_name_uk on od.chair (nr_company, nr_branch, lower(vc_name));
alter table od.chair enable row level security;

alter table od.appointment add column nr_category bigint;
alter table od.appointment add column nr_chair bigint;
alter table od.appointment add constraint appointment_category_fk foreign key (nr_company, nr_branch, nr_category)
  references od.appointment_category (nr_company, nr_branch, nr_category);
alter table od.appointment add constraint appointment_chair_fk foreign key (nr_company, nr_branch, nr_chair)
  references od.chair (nr_company, nr_branch, nr_chair);
create index appointment_chair_idx on od.appointment (nr_company, nr_branch, nr_chair, dh_start) where nr_chair is not null;

create table od.appointment_tag (
  nr_company      bigint         not null,
  nr_branch       bigint         not null,
  nr_appointment  bigint         not null,
  nr_marker       bigint         not null,
  nr_operator     bigint,
  dh_created      timestamptz    not null default now(),
  dh_updated      timestamptz    not null default now(),
  constraint appointment_tag_pk primary key (nr_company, nr_branch, nr_appointment, nr_marker),
  constraint appointment_tag_appointment_fk foreign key (nr_company, nr_branch, nr_appointment)
    references od.appointment (nr_company, nr_branch, nr_appointment) on delete cascade,
  constraint appointment_tag_marker_fk foreign key (nr_company, nr_branch, nr_marker)
    references od.appointment_marker (nr_company, nr_branch, nr_marker)
);
create index appointment_tag_marker_idx on od.appointment_tag (nr_company, nr_branch, nr_marker);
alter table od.appointment_tag enable row level security;

alter table od.branch_setting add column id_color_by_category boolean not null default false;
alter table od.branch_setting add column it_agenda_mode smallint not null default 1;
alter table od.branch_setting add constraint branch_setting_agenda_mode_check check (it_agenda_mode in (1, 2));
