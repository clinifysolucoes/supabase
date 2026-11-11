-- ============================================================================
-- Controle de Indicacao: quem indicou cada paciente (outro paciente da
-- filial em od.patient.nr_referrer, ou o nome livre que ja existia em
-- vc_referral), o ranking de quem mais indica com conversao e valor, e o
-- registro do retorno dado a quem indicou (brinde, desconto, agradecimento).
--
--   od.patient.nr_referrer  paciente que indicou (opcional)
--   od.referral_reward      recompensa por indicacao (uma por paciente indicado)
--
-- Tela nova REFERRALS (Gestao).
-- ============================================================================

alter table od.patient add column nr_referrer bigint;
alter table od.patient add constraint patient_referrer_fk foreign key (nr_company, nr_branch, nr_referrer)
  references od.patient (nr_company, nr_branch, nr_patient);
alter table od.patient add constraint patient_referrer_check check (nr_referrer is null or nr_referrer <> nr_patient);
create index patient_referrer_idx on od.patient (nr_company, nr_branch, nr_referrer) where nr_referrer is not null;

create table od.referral_reward (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_patient       bigint         not null,
  vc_referrer      varchar(120)   not null,
  dt_reward        date           not null,
  vc_reward        varchar(200)   not null,
  vl_reward        numeric(12,2),
  it_status        smallint       not null default 1,
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint referral_reward_pk primary key (nr_company, nr_branch, nr_patient),
  constraint referral_reward_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint referral_reward_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint referral_reward_reward_check check (length(trim(vc_reward)) > 0),
  constraint referral_reward_value_check check (vl_reward is null or vl_reward >= 0),
  constraint referral_reward_status_check check (it_status in (1, 90))
);
alter table od.referral_reward enable row level security;

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000014', 'REFERRALS', 'Indicações', 'Gestão', 19);
