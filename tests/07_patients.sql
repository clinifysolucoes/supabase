-- ============================================================================
-- Pacientes (RPCs em ad, tabelas em od): cadastro completo, normalizacao
-- (CPF/telefone/CEP so digitos, e-mail minusculo, UF maiuscula), validacoes,
-- update parcial, busca paginada, notas gerais, permissao por tela PATIENTS,
-- event_log e RLS.
--   Ana  = administradora da empresa
--   Bia  = perfil "Recepcao": PATIENTS ler + criar (sem alterar)
--   Caio = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/07_patients.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

-- helper: a chamada tem que falhar com a chave esperada
create function pg_temp.expect_patient_error(p_json jsonb, p_key text, p_msg text)
returns void language plpgsql as $$
declare _ok boolean := false;
begin
  begin
    perform ad.patient_save(p_json);
    _ok := true;
  exception when others then
    if sqlerrm not like '%' || p_key || '%' then raise; end if;
  end;
  if _ok then
    raise exception 'FALHA: % (era para dar %)', p_msg, p_key;
  end if;
end $$;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000041', 'ana.pac@test.local',  '{"name": "Ana Pac"}'),
  ('00000000-0000-0000-0000-000000000042', 'bia.pac@test.local',  '{"name": "Bia Pac"}'),
  ('00000000-0000-0000-0000-000000000043', 'caio.pac@test.local', '{"name": "Caio Pac"}');

do $$
begin
  assert (select uu_screen from ad.screen where vc_code = 'PATIENTS') = '0d6a1f3e-1b2c-4d5e-8f90-000000000006',
    'tela PATIENTS deveria existir com o uuid fixo';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana: cadastro, normalizacao, validacoes, update parcial'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000041","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r    jsonb;
  _p    jsonb;
  _ca   bigint;
  _p1   bigint;
  _p2   bigint;
  _p3   bigint;
  _prof bigint;
  _uu   uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000006';
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Pac"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  -- lista vazia, com a permissao do admin
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r ->> 'qt_total')::int = 0 and jsonb_array_length(_r -> 'patients') = 0, 'lista vazia';
  assert (_r -> 'permission' ->> 'id_update')::boolean, 'admin tem tudo';

  -- P1: com mascara em tudo (o banco guarda so digitos), e-mail maiusculo, UF minuscula
  _r := ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', '  Mariana Souza ', 'vc_cpf', '529.982.247-25', 'vc_rg', '12.345.678-9',
          'dt_birth', '1990-05-20', 'it_gender', 2, 'it_source', 4, 'vc_referral', 'Dra. Paula',
          'vc_mobile', '(11) 98765-4321', 'vc_phone', '(11) 3333-4444', 'vc_email', 'MARIANA@Teste.com',
          'vc_zip', '01310-100', 'vc_state', 'sp', 'vc_city', 'São Paulo', 'vc_address', 'Av. Paulista',
          'vc_address_number', '1000', 'vc_district', 'Bela Vista', 'vc_profession', 'Arquiteta',
          'vc_notes', 'Alergia a latex'));
  _p1 := (_r ->> 'nr_patient')::bigint;
  assert _p1 = 1, 'primeiro paciente da filial = 1';

  _r := ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', _p1));
  _p := _r -> 'patient';
  assert _p ->> 'vc_name' = 'Mariana Souza', 'nome com trim: ' || (_p ->> 'vc_name');
  assert _p ->> 'vc_cpf' = '52998224725', 'cpf so digitos: ' || (_p ->> 'vc_cpf');
  assert _p ->> 'vc_rg' = '12.345.678-9', 'rg como digitado';
  assert _p ->> 'vc_mobile' = '11987654321' and _p ->> 'vc_phone' = '1133334444', 'telefones so digitos';
  assert _p ->> 'vc_email' = 'mariana@teste.com', 'e-mail minusculo';
  assert _p ->> 'vc_zip' = '01310100' and _p ->> 'vc_state' = 'SP', 'cep digitos e uf maiuscula';
  assert (_p ->> 'qt_age')::int = extract(year from age(current_date, date '1990-05-20'))::int, 'idade';
  assert (_p ->> 'it_status')::int = 1 and not (_p ->> 'id_no_email')::boolean, 'ativo, com e-mail';
  assert _p ? 'dh_created' and not (_p ? 'nr_operator'), 'ficha traz dh_created e esconde nr_operator';
  assert jsonb_array_length(_r -> 'notes') = 0, 'sem notas';

  -- P2: sem CPF, com prontuario; P3: menor com representante legal
  _r := ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Carlos Lima', 'dt_birth', '1985-01-01', 'vc_record_number', '000123', 'it_source', 1));
  _p2 := (_r ->> 'nr_patient')::bigint;
  _r := ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Ana Beatriz Silva', 'vc_nickname', 'Bia', 'dt_birth', '2015-03-10', 'it_gender', 2,
          'vc_guardian_name', 'Joana Silva', 'vc_guardian_cpf', '111.444.777-35', 'vc_guardian_phone', '11 91111-2222',
          'vc_mother_name', 'Joana Silva', 'id_no_email', true, 'vc_email', 'ignorado@x.com'));
  _p3 := (_r ->> 'nr_patient')::bigint;
  assert _p2 = 2 and _p3 = 3, 'sequencial por filial';
  _r := ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', _p3));
  assert _r -> 'patient' ->> 'vc_email' is null and (_r -> 'patient' ->> 'id_no_email')::boolean, 'nao possui e-mail limpa o e-mail';
  assert _r -> 'patient' ->> 'vc_guardian_cpf' = '11144477735', 'cpf do representante so digitos';

  -- validacoes
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'Outra Pessoa', 'dt_birth', '1980-01-01', 'vc_cpf', '529.982.247-25'), 'PATIENT_CPF_IN_USE', 'cpf repetido');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_cpf', '111.111.111-11'), 'PATIENT_CPF_INVALID', 'cpf invalido');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_mother_cpf', '123'), 'PATIENT_CPF_INVALID', 'cpf da mae invalido');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', '   ', 'dt_birth', '1980-01-01'), 'PATIENT_NAME_REQUIRED', 'sem nome');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X'), 'PATIENT_BIRTH_REQUIRED', 'sem nascimento');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '2999-01-01'), 'PATIENT_BIRTH_INVALID', 'nascimento no futuro');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '20/05/1990'), 'PATIENT_VALUE_INVALID', 'data fora do ISO');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '2020-13-01'), 'PATIENT_VALUE_INVALID', 'mes 13');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_email', 'nao-e-email'), 'PATIENT_EMAIL_INVALID', 'e-mail invalido');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_mobile', '123'), 'PATIENT_PHONE_INVALID', 'celular curto');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_zip', '123'), 'PATIENT_ZIP_INVALID', 'cep curto');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'vc_state', 'S1'), 'PATIENT_STATE_INVALID', 'uf invalida');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'it_gender', 7), 'PATIENT_VALUE_INVALID', 'genero 7');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X', 'dt_birth', '1980-01-01', 'it_source', 'abc'), 'PATIENT_VALUE_INVALID', 'origem texto');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'X', 'nr_company', _ca, 'nr_branch', 1),
         'PATIENT_ACTION_INVALID', 'acao X');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
         'vc_name', 'X'), 'PATIENT_REQUIRED', 'U sem nr_patient');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
         'nr_patient', 999, 'vc_name', 'X'), 'PATIENT_NOT_FOUND', 'U inexistente');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
         'nr_patient', _p1, 'it_status', 7), 'PATIENT_STATUS_INVALID', 'situacao 7');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
         'nr_patient', _p1, 'dt_birth', null), 'PATIENT_BIRTH_REQUIRED', 'U limpando nascimento');
  perform pg_temp.expect_patient_error(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca),
         'PATIENT_BRANCH_REQUIRED', 'sem filial');

  -- update parcial: so o apelido muda; null limpa o RG; alerta de retorno
  perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p1, 'vc_nickname', 'Mari'));
  perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p1, 'vc_rg', null, 'dt_return_alert', '2026-12-01', 'vc_return_alert', 'Retorno da limpeza'));
  _r := ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', _p1));
  _p := _r -> 'patient';
  assert _p ->> 'vc_nickname' = 'Mari' and _p ->> 'vc_cpf' = '52998224725' and _p ->> 'vc_mobile' = '11987654321',
    'update parcial mantem o resto';
  assert _p ->> 'vc_rg' is null and _p ->> 'dt_return_alert' = '2026-12-01', 'null limpa; alerta gravado';
  -- mesmo CPF no proprio paciente nao conflita
  perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p1, 'vc_cpf', '529.982.247-25'));

  -- inativar P2
  perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p2, 'it_status', 90));

  -- busca
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r ->> 'qt_total')::int = 2, 'ativos: 2, veio ' || (_r ->> 'qt_total');
  assert _r -> 'patients' -> 0 ->> 'vc_name' = 'Ana Beatriz Silva', 'ordem por nome';
  assert (_r -> 'patients' -> 1 ->> 'qt_age')::int >= 36, 'idade na lista';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'id_include_inactive', true));
  assert (_r ->> 'qt_total')::int = 3, 'com inativos: 3';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'mari'));
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'patients' -> 0 ->> 'vc_name' = 'Mariana Souza', 'busca por nome';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', '%silva'));
  assert (_r ->> 'qt_total')::int = 1, 'curinga para sobrenome';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'bia'));
  assert (_r ->> 'qt_total')::int = 1, 'busca por apelido';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', '529.982'));
  assert (_r ->> 'qt_total')::int = 1, 'busca por inicio do cpf com mascara';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', '98765'));
  assert (_r ->> 'qt_total')::int = 1, 'busca por trecho do celular';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'carlos'));
  assert (_r ->> 'qt_total')::int = 0, 'inativo nao aparece por padrao';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', '000123', 'id_include_inactive', true));
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'patients' -> 0 ->> 'vc_name' = 'Carlos Lima', 'busca por prontuario';
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'qt_page_size', 1, 'nr_page', 2));
  assert (_r ->> 'qt_total')::int = 2 and jsonb_array_length(_r -> 'patients') = 1
     and _r -> 'patients' -> 0 ->> 'vc_name' = 'Mariana Souza', 'paginacao';

  -- notas gerais
  _r := ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'nr_patient', _p1, 'vc_note', 'Prefere horarios de manha'));
  assert (_r ->> 'nr_note')::int = 1, 'primeira nota';
  perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p1, 'vc_note', 'Trouxe exames'));
  _r := ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', _p1));
  assert jsonb_array_length(_r -> 'notes') = 2 and (_r -> 'notes' -> 0 ->> 'nr_note')::int = 2
     and _r -> 'notes' -> 0 ->> 'vc_user' = 'Ana Pac', 'notas da mais recente, com autor';
  perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'D', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', _p1, 'nr_note', 1));
  _r := ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', _p1));
  assert jsonb_array_length(_r -> 'notes') = 1, 'nota excluida some';
  begin
    perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'D', 'nr_company', _ca, 'nr_branch', 1,
              'nr_patient', _p1, 'nr_note', 1));
    raise exception 'FALHA: excluiu nota ja excluida';
  exception when others then
    if sqlerrm not like '%PATIENT_NOTE_NOT_FOUND%' then raise; end if;
  end;
  begin
    perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'nr_patient', _p1, 'vc_note', '   '));
    raise exception 'FALHA: nota vazia';
  exception when others then
    if sqlerrm not like '%PATIENT_NOTE_REQUIRED%' then raise; end if;
  end;

  -- perfil Recepcao (PATIENTS ler + criar) para a Bia
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Recepcao', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'bia.pac@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));

  -- log de atividades na tela PATIENTS: 3 cadastros + 4 alteracoes + 3 notas
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'uu_screen', _uu));
  assert (_r ->> 'qt_total')::int = 10, 'eventos de pacientes, veio ' || (_r ->> 'qt_total');
  assert (select count(*) from jsonb_array_elements(_r -> 'events') e where e ->> 'vc_summary' like 'Paciente Carlos Lima inativado') = 1,
    'resumo da inativacao';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia (Recepcao): le e cria, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000042","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
  _r  jsonb;
begin
  _r := ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r ->> 'qt_total')::int = 2, 'Bia lista os pacientes ativos';
  assert (_r -> 'permission' ->> 'id_create')::boolean and not (_r -> 'permission' ->> 'id_update')::boolean, 'permission na lista';

  _r := ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Paciente da Bia', 'dt_birth', '2000-01-01'));
  assert (_r ->> 'nr_patient')::int = 4, 'Bia cadastra';

  begin
    perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_patient', 1, 'vc_nickname', 'X'));
    raise exception 'FALHA: Bia alterou paciente';
  exception when others then
    if sqlerrm not like '%PATIENT_FORBIDDEN%' then raise; end if;
  end;

  -- nota: criar pode (criar ou alterar), excluir nao (alterar)
  perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'nr_patient', 1, 'vc_note', 'Ligou para confirmar'));
  begin
    perform ad.patient_note_save(jsonb_build_object('nr_version', 1, 'vc_action', 'D', 'nr_company', _ca, 'nr_branch', 1,
              'nr_patient', 1, 'nr_note', 2));
    raise exception 'FALHA: Bia excluiu nota';
  exception when others then
    if sqlerrm not like '%PATIENT_NOTE_FORBIDDEN%' then raise; end if;
  end;

  -- RLS: so as linhas da propria filial
  assert (select count(*) from od.patient) = 4, 'RLS: Bia ve os 4 pacientes da filial';
  assert (select count(*) from od.patient_note) = 3, 'RLS: Bia ve as notas (inclusive a excluida logicamente)';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Caio (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000043","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
begin
  begin
    perform ad.patient_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
    raise exception 'FALHA: Caio listou pacientes de outra empresa';
  exception when others then
    if sqlerrm not like '%PATIENT_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.patient_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_patient', 1));
    raise exception 'FALHA: Caio leu ficha de outra empresa';
  exception when others then
    if sqlerrm not like '%PATIENT_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'Z', 'dt_birth', '2000-01-01'));
    raise exception 'FALHA: Caio criou paciente';
  exception when others then
    if sqlerrm not like '%PATIENT_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.patient) = 0, 'RLS: Caio nao ve pacientes';
  assert (select count(*) from od.patient_note) = 0, 'RLS: Caio nao ve notas';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.patient_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou ad.patient_list';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from od.patient;
    raise exception 'FALHA: anon leu od.patient';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 07_patients'
