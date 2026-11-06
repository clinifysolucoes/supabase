-- ============================================================================
-- Configuracoes, parte C: exportacao de planilhas (ad.data_export) e lixeira
-- (ad.trash_list / ad.trash_restore, que usa a RPC de cada tela).
--   Mel = administradora da empresa
--   Ivo = recepcao (pacientes e agenda: ler e alterar; configuracoes: ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/20_export_trash.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f7', 'mel.cfgc@test.local', '{"name": "Mel ConfigC"}'),
  ('00000000-0000-0000-0000-0000000000f8', 'ivo.cfgc@test.local', '{"name": "Ivo ConfigC"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: exportar e lixeira'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _cat   jsonb;
  _rec   bigint;
  _pa    bigint;
  _pb    bigint;
  _ana   bigint;
  _ap    bigint;
  _e1    bigint;
  _note  bigint;
  _mat   bigint;
  _prof  bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica ConfigC"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  perform ad.fin_setup(_base);
  _cat := ad.fin_catalog(_base);
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Export", "dt_birth": "1990-01-01",
           "vc_cpf": "529.982.247-25", "vc_mobile": "(41) 99999-0000"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Bia Export", "dt_birth": "1985-05-05"}'::jsonb) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Ana"}'::jsonb) ->> 'nr_professional')::bigint;
  _ap := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _ana,
           'dh_start', '2030-03-04T09:00:00-03:00', 'dh_end', '2030-03-04T09:30:00-03:00')) ->> 'nr_appointment')::bigint;
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
           'vc_description', 'Tratamento', 'vl_amount', 300, 'dt_due', '2030-03-04', 'qt_installments', 3)) ->> 'nr_entry')::bigint;
  _mat := (ad.material_save(_base || '{"vc_action": "I", "vc_name": "Resina", "vl_package_price": 80}'::jsonb) ->> 'nr_material')::bigint;
  _note := (ad.patient_note_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_note', 'Alergia a látex'))
           ->> 'nr_note')::bigint;

  -- exportar: validacoes
  perform pg_temp.expect_error('data_export', _base || '{"vc_kind": "x"}'::jsonb, 'EXPORT_KIND_INVALID');
  perform pg_temp.expect_error('data_export', _base || '{"vc_kind": "finance"}'::jsonb, 'EXPORT_PERIOD_INVALID');
  perform pg_temp.expect_error('data_export', _base || '{"vc_kind": "agenda", "dt_from": "2030-01-01", "dt_to": "2031-06-01"}'::jsonb,
            'EXPORT_PERIOD_INVALID');

  _r := ad.data_export(_base || '{"vc_kind": "patients"}'::jsonb);
  assert (_r ->> 'qt_rows')::int = 2 and _r -> 'columns' ->> 1 = 'Nome', 'pacientes: 2 linhas';
  assert _r -> 'rows' -> 0 ->> 1 = 'Ana Export' and _r -> 'rows' -> 0 ->> 3 = '52998224725', 'pacientes: ordem e CPF';
  assert jsonb_array_length(_r -> 'rows' -> 0) = jsonb_array_length(_r -> 'columns'), 'linha do tamanho das colunas';

  _r := ad.data_export(_base || '{"vc_kind": "finance", "dt_from": "2030-01-01", "dt_to": "2030-12-31"}'::jsonb);
  assert (_r ->> 'qt_rows')::int = 3 and _r -> 'rows' -> 0 ->> 14 = '1/3' and _r -> 'rows' -> 0 ->> 4 = 'Ana Export',
    'financeiro: 3 parcelas, veio ' || (_r -> 'rows' -> 0)::text;
  _r := ad.data_export(_base || '{"vc_kind": "finance", "it_kind": 2, "dt_from": "2030-01-01", "dt_to": "2030-12-31"}'::jsonb);
  assert (_r ->> 'qt_rows')::int = 0, 'financeiro: so a pagar';

  _r := ad.data_export(_base || '{"vc_kind": "agenda", "dt_from": "2030-03-01", "dt_to": "2030-03-31"}'::jsonb);
  assert (_r ->> 'qt_rows')::int = 1 and _r -> 'rows' -> 0 ->> 1 = '09:00' and _r -> 'rows' -> 0 ->> 8 = 'Agendado',
    'agenda: horario no fuso da filial';

  _r := ad.data_export(_base || '{"vc_kind": "procedures"}'::jsonb);
  assert (_r ->> 'qt_rows')::int >= 0 and jsonb_array_length(_r -> 'columns') = 11, 'procedimentos';

  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'data_export'
                    and e.vc_summary = 'Exportação: pacientes (2 linhas)'), 'exportacao no log';
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'data_export'
                        and e.js_detail::text like '%Ana%'), 'log sem dados pessoais';

  -- lixeira: vazia
  assert jsonb_array_length(ad.trash_list(_base) -> 'items') = 0, 'lixeira vazia';
  perform pg_temp.expect_error('trash_list', _base || '{"vc_kind": "x"}'::jsonb, 'TRASH_KIND_INVALID');

  -- exclui um de cada
  perform ad.patient_save(_base || jsonb_build_object('vc_action', 'U', 'nr_patient', _pb, 'it_status', 90));
  perform ad.patient_note_save(_base || jsonb_build_object('vc_action', 'D', 'nr_patient', _pa, 'nr_note', _note));
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _ap, 'it_status', 90));
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'CANCEL', 'nr_entry', _e1));
  perform ad.material_save(_base || jsonb_build_object('vc_action', 'U', 'nr_material', _mat, 'it_status', 90));

  _r := ad.trash_list(_base);
  assert jsonb_array_length(_r -> 'items') = 5, 'lixeira com 5 itens, veio ' || (_r -> 'items')::text;
  assert jsonb_array_length(_r -> 'kinds') = 6, 'admin ve todos os tipos';
  assert (select bool_and((x ->> 'id_restore')::boolean) from jsonb_array_elements(_r -> 'items') x), 'admin restaura';
  assert (select x ->> 'vc_user' from jsonb_array_elements(_r -> 'items') x where x ->> 'vc_kind' = 'patient') = 'Mel ConfigC',
    'quem excluiu';
  assert jsonb_array_length(ad.trash_list(_base || '{"vc_kind": "fin_entry"}'::jsonb) -> 'items') = 1, 'filtro por tipo';
  assert jsonb_array_length(ad.trash_list(_base || '{"vc_search": "látex"}'::jsonb) -> 'items') = 1, 'busca no detalhe';

  -- restaurar
  perform pg_temp.expect_error('trash_restore', _base || jsonb_build_object('vc_kind', 'patient', 'nr_key', _pa), 'TRASH_NOT_FOUND');
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'patient', 'nr_key', _pb));
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'patient_note', 'nr_key', _note, 'nr_parent', _pa));
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'appointment', 'nr_key', _ap));
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'fin_entry', 'nr_key', _e1));
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'material', 'nr_key', _mat));
  assert jsonb_array_length(ad.trash_list(_base) -> 'items') = 0, 'tudo restaurado';
  assert (select it_status from od.appointment where nr_company = _ca and nr_appointment = _ap) = 1, 'consulta agendada de novo';
  assert (select it_status from od.patient_note where nr_company = _ca and nr_note = _note) = 1, 'nota de volta';
  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'patient_note'
                    and e.vc_summary like 'Nota restaurada%'), 'restauracao no log da tela';

  -- de novo na lixeira para o Ivo
  perform ad.patient_save(_base || jsonb_build_object('vc_action', 'U', 'nr_patient', _pb, 'it_status', 90));
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'CANCEL', 'nr_entry', _e1));
  perform set_config('test.nr_patient', _pb::text, false);
  perform set_config('test.nr_entry', _e1::text, false);

  -- Ivo: pacientes e agenda (ler + alterar), configuracoes (ler)
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'id_read', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000009', 'id_read', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.cfgc@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

\echo '== Ivo: so os tipos que le, sem exportar'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  -- exportar exige alterar Configuracoes
  perform pg_temp.expect_error('data_export', _base || '{"vc_kind": "patients"}'::jsonb, 'EXPORT_FORBIDDEN');
  _r := ad.trash_list(_base);
  assert _r -> 'kinds' = '["patient", "patient_note", "appointment"]'::jsonb, 'tipos do Ivo, veio ' || (_r -> 'kinds')::text;
  assert jsonb_array_length(_r -> 'items') = 1 and _r -> 'items' -> 0 ->> 'vc_kind' = 'patient', 'Ivo nao ve o financeiro';
  -- a conta cancelada: a RPC do financeiro barra
  perform pg_temp.expect_error('trash_restore', _base || jsonb_build_object('vc_kind', 'fin_entry',
            'nr_key', current_setting('test.nr_entry')::bigint), 'FIN_ENTRY_FORBIDDEN');
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'patient', 'nr_key', current_setting('test.nr_patient')::bigint));
  assert jsonb_array_length(ad.trash_list(_base) -> 'items') = 0, 'Ivo restaurou o paciente';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.trash_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou trash_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 20_export_trash'
