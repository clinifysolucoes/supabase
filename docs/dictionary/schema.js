/* GERADO por tools/gen-dictionary.mjs a partir de schema.json - nao editar */
window.DICTIONARY = {
  "project": "Supabase multi-company login",
  "subtitle": "Base multi-empresa / multi-filial do futuro sistema de odontologia",
  "schema": "ad",
  "schema_title": "AD - Administrative",
  "schemas": {
    "ad": "AD - Administrative (empresas, filiais, usuários, perfis, telas, logs)",
    "od": "OD - Odontologia (precificação e pacientes: tabelas e helpers; RPCs expostas ficam em ad)",
    "private": "helpers de RLS, fora da API"
  },
  "updated": "2026-11-06",
  "prefixes": {
    "nr_": "Numérico / identificador (bigint, smallint)",
    "vc_": "Texto (varchar, text)",
    "it_": "Indicador / tipo codificado (smallint com lista de valores)",
    "id_": "Booleano (true/false)",
    "dt_": "Data (date)",
    "dh_": "Data e hora com fuso (timestamptz)",
    "qt_": "Quantidade",
    "vl_": "Valor monetário (numeric)",
    "pc_": "Percentual",
    "uu_": "UUID"
  },
  "audit_columns": [
    {
      "name": "nr_operator",
      "type": "bigint",
      "nullable": true,
      "default": null,
      "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
    },
    {
      "name": "dh_created",
      "type": "timestamptz",
      "nullable": false,
      "default": "now()",
      "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
    },
    {
      "name": "dh_updated",
      "type": "timestamptz",
      "nullable": false,
      "default": "now()",
      "description": "Data/hora da última atualização (trigger ad.trg_audit)."
    }
  ],
  "tables": [
    {
      "name": "company",
      "title": "Empresa",
      "description": "Empresa (tenant principal). Toda informação de negócio pertence a uma empresa e, dentro dela, a uma filial.",
      "rls": "SELECT: empresas em que o usuário tem pelo menos uma filial acessível (private.fn_my_companies). Escrita só via company_create / company_update.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Número da empresa."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome da empresa."
        },
        {
          "name": "vc_cnpj",
          "type": "varchar(14)",
          "uk": "company_vc_cnpj_uk",
          "nullable": true,
          "description": "CNPJ sem pontuação, 14 posições. Aceita o CNPJ alfanumérico (12 posições [A-Z0-9] + 2 dígitos). Único quando informado."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "nullable": true,
          "description": "E-mail de contato da empresa (minúsculo)."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone principal (DDD + número, livre)."
        },
        {
          "name": "it_size",
          "type": "smallint",
          "nullable": true,
          "description": "Porte da empresa.",
          "values": {
            "10": "MEI",
            "20": "Micro empresa (ME)",
            "30": "Pequeno porte (EPP)",
            "40": "Médio porte",
            "50": "Grande porte"
          }
        },
        {
          "name": "vc_address",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Logradouro."
        },
        {
          "name": "vc_address_number",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Número do endereço."
        },
        {
          "name": "vc_address_extra",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Complemento do endereço."
        },
        {
          "name": "vc_district",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Bairro."
        },
        {
          "name": "vc_city",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Cidade."
        },
        {
          "name": "vc_state",
          "type": "char(2)",
          "nullable": true,
          "description": "UF (2 letras maiúsculas)."
        },
        {
          "name": "vc_zip_code",
          "type": "varchar(8)",
          "nullable": true,
          "description": "CEP, 8 dígitos sem pontuação."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da empresa.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "dh_status",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última mudança de situação."
        },
        {
          "name": "id_blocked",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Empresa bloqueada pela plataforma (inadimplência, abuso). Bloqueada = ninguém entra; o motivo aparece em session_context.blocked."
        },
        {
          "name": "dh_blocked",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do bloqueio."
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio, exibido ao usuário."
        },
        {
          "name": "it_mfa_policy",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Autenticação em dois fatores (app autenticador) obrigatória: sem o segundo fator confirmado na sessão, quem precisa dele fica sem acesso à empresa. Só o administrador altera, e para ligar precisa estar com 2FA.",
          "values": {
            "0": "Não exige",
            "1": "Exige dos administradores",
            "2": "Exige de todos os usuários"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "branch",
      "title": "Filial",
      "description": "Filial (unidade/clínica) da empresa. PK composta (nr_company, nr_branch) com numeração sequencial por empresa. Toda tabela de negócio futura referencia (nr_company, nr_branch).",
      "rls": "SELECT: filiais acessíveis ao usuário (private.fn_my_branches). Escrita só via company_create (matriz), branch_create e branch_update.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "nullable": false,
          "description": "Número da filial, sequencial dentro da empresa (1 = matriz criada com a empresa)."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome fantasia da filial."
        },
        {
          "name": "vc_legal_name",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Razão social."
        },
        {
          "name": "vc_cnpj",
          "type": "varchar(14)",
          "uk": "branch_vc_cnpj_uk",
          "nullable": true,
          "description": "CNPJ da filial, sem pontuação (alfanumérico aceito). Único quando informado."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "nullable": true,
          "description": "E-mail de contato da filial."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone principal."
        },
        {
          "name": "it_size",
          "type": "smallint",
          "nullable": true,
          "description": "Porte da filial.",
          "values": {
            "10": "MEI",
            "20": "Micro empresa (ME)",
            "30": "Pequeno porte (EPP)",
            "40": "Médio porte",
            "50": "Grande porte"
          }
        },
        {
          "name": "it_tax_regime",
          "type": "smallint",
          "nullable": true,
          "description": "Regime tributário.",
          "values": {
            "10": "Simples Nacional MEI (SIMEI)",
            "20": "Simples Nacional",
            "30": "Lucro Real",
            "40": "Lucro Presumido",
            "50": "Lucro Arbitrado"
          }
        },
        {
          "name": "vc_state_registration",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Inscrição estadual."
        },
        {
          "name": "vc_city_registration",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Inscrição municipal."
        },
        {
          "name": "vc_address",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Logradouro."
        },
        {
          "name": "vc_address_number",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Número do endereço."
        },
        {
          "name": "vc_address_extra",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Complemento do endereço."
        },
        {
          "name": "vc_district",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Bairro."
        },
        {
          "name": "vc_city",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Cidade."
        },
        {
          "name": "vc_state",
          "type": "char(2)",
          "nullable": true,
          "description": "UF."
        },
        {
          "name": "vc_zip_code",
          "type": "varchar(8)",
          "nullable": true,
          "description": "CEP, 8 dígitos."
        },
        {
          "name": "vc_timezone",
          "type": "varchar(60)",
          "nullable": false,
          "default": "'America/Sao_Paulo'",
          "description": "Fuso horário IANA da filial (validado em pg_timezone_names). Base da agenda da clínica."
        },
        {
          "name": "vc_phone_extra",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Telefone adicional (só dígitos)."
        },
        {
          "name": "vc_technical_name",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Responsável técnico da clínica."
        },
        {
          "name": "vc_technical_cro",
          "type": "varchar(20)",
          "nullable": true,
          "description": "CRO do responsável técnico."
        },
        {
          "name": "vc_technical_cro_state",
          "type": "varchar(2)",
          "nullable": true,
          "description": "UF do CRO."
        },
        {
          "name": "vc_forum_city",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Cidade do foro dos contratos (nulo = a da clínica)."
        },
        {
          "name": "id_main",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Matriz. Única por empresa (índice branch_id_main_uk)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da filial.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "dh_status",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última mudança de situação."
        },
        {
          "name": "id_blocked",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Filial bloqueada pela plataforma."
        },
        {
          "name": "dh_blocked",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do bloqueio."
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "app_user",
      "title": "Usuário",
      "description": "Usuário do sistema. A autenticação (e-mail, senha, OTP, social, 2FA, tentativas) é do Supabase Auth (auth.users); aqui ficam o id numérico, nome e dados do app. Criado automaticamente pelo trigger ad.trg_auth_user_sync no signup.",
      "rls": "SELECT: o próprio cadastro, ou cadastros de usuários vinculados a uma empresa que o usuário administra (private.fn_is_admin_of_user). Escrita só via user_update (próprio) e triggers.",
      "columns": [
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Código do usuário."
        },
        {
          "name": "uu_auth",
          "type": "uuid",
          "uk": "app_user_uu_auth_uk",
          "fk": "auth.users.id",
          "nullable": false,
          "description": "Id do usuário no Supabase Auth (claim sub do JWT = auth.uid()). ON DELETE CASCADE."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome do usuário (vem de raw_user_meta_data.name no signup)."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "uk": "app_user_vc_email_uk",
          "nullable": true,
          "description": "E-mail em minúsculo, espelho de auth.users.email (trigger). Nulo em login só por telefone. Usado por company_user_save para localizar quem vincular."
        },
        {
          "name": "vc_cpf",
          "type": "varchar(11)",
          "uk": "app_user_vc_cpf_uk",
          "nullable": true,
          "description": "CPF, 11 dígitos, validado (ad.fn_cpf_is_valid). Único quando informado."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone fixo."
        },
        {
          "name": "vc_mobile",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Celular."
        },
        {
          "name": "vc_avatar_url",
          "type": "text",
          "nullable": true,
          "description": "URL da foto no Supabase Storage."
        },
        {
          "name": "it_level",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Nível do usuário na plataforma. Alterável só por service_role.",
          "values": {
            "0": "Normal",
            "100": "Administrador da plataforma (suporte)"
          }
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do usuário na plataforma. Bloqueado/inativo não enxerga nada (private.fn_current_user_nr retorna NULL).",
          "values": {
            "1": "Ativo",
            "80": "Bloqueado",
            "90": "Inativo"
          }
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio (devolvido em SESSION_USER_BLOCKED)."
        },
        {
          "name": "dh_last_login",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do último session_context (login no app)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "access_profile",
      "title": "Perfil de acesso",
      "description": "Perfil de acesso da empresa (Administrador, Dentista, Recepção...). Numeração sequencial por empresa. company_create cria 1 = Administrador (nível 100) e 2 = Usuário (nível 0). A ligação perfil x telas ainda não existe neste projeto.",
      "rls": "SELECT: perfis das empresas acessíveis (private.fn_my_companies). Escrita só via access_profile_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_profile",
          "type": "bigint",
          "pk": 2,
          "nullable": false,
          "description": "Código do perfil, sequencial dentro da empresa."
        },
        {
          "name": "vc_name",
          "type": "varchar(30)",
          "uk": "access_profile_vc_name_uk (nr_company, vc_name)",
          "nullable": false,
          "description": "Nome do perfil, único na empresa."
        },
        {
          "name": "it_level",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Nível hierárquico 0..100. 100 = administrador da empresa (private.fn_is_company_admin).",
          "values": {
            "0": "Usuário comum",
            "100": "Administrador da empresa"
          }
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do perfil. Inativo não concede acesso.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "company_user",
      "title": "Empresa x Usuário",
      "description": "Vínculo do usuário com a empresa (multi-empresa: um usuário em N empresas). Situação do usuário DENTRO da empresa, independente da situação na plataforma.",
      "rls": "SELECT: os próprios vínculos, ou todos os vínculos das empresas que o usuário administra. Escrita só via company_create (criador) e company_user_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 2,
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Código do usuário."
        },
        {
          "name": "nr_company_user",
          "type": "bigint",
          "uk": "company_user_nr_company_user_uk (nr_company, nr_company_user)",
          "nullable": false,
          "description": "Código do usuário dentro da empresa, sequencial (1 = criador). Útil como código curto de operador/profissional."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do usuário na empresa.",
          "values": {
            "1": "Ativo",
            "80": "Bloqueado",
            "90": "Inativo"
          }
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio na empresa (devolvido em session_context.blocked). Limpo ao reativar."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "branch_user_profile",
      "title": "Filial x Usuário x Perfil",
      "description": "Perfis do usuário em cada filial (multi-filial). É esta tabela que dá acesso: sem linha aqui numa filial ativa, o usuário não entra na empresa (SESSION_WITHOUT_PROFILE). ON DELETE CASCADE de branch e company_user.",
      "rls": "SELECT: os próprios vínculos, ou todos das empresas que o usuário administra. Escrita só via company_create, branch_create e company_user_save (ad.fn_set_user_branches).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 3,
          "fk": "company_user.nr_user",
          "nullable": false,
          "description": "Código do usuário (precisa estar vinculado à empresa em company_user)."
        },
        {
          "name": "nr_profile",
          "type": "bigint",
          "pk": 4,
          "fk": "access_profile.nr_profile",
          "nullable": false,
          "description": "Perfil do usuário nesta filial."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "access_log",
      "title": "Log de acesso",
      "description": "Uma linha por session_context (login/restauração de sessão no app). IP e user-agent são lidos dos headers HTTP do request pelo PostgREST (request.headers).",
      "rls": "SELECT: os próprios acessos. Escrita só via session_context.",
      "columns": [
        {
          "name": "nr_access",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Número do acesso."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que acessou."
        },
        {
          "name": "nr_company",
          "type": "bigint",
          "nullable": true,
          "description": "Empresa que o app abriu (quando informada)."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "nullable": true,
          "description": "Filial que o app abriu (quando informada)."
        },
        {
          "name": "it_app",
          "type": "smallint",
          "nullable": true,
          "description": "Tipo de aplicativo.",
          "values": {
            "1": "Web",
            "2": "Android",
            "3": "iOS",
            "9": "Outro"
          }
        },
        {
          "name": "vc_ip",
          "type": "varchar(60)",
          "nullable": true,
          "description": "IP de origem (header x-forwarded-for, primeiro valor)."
        },
        {
          "name": "vc_device",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Dispositivo/modelo informado pelo app."
        },
        {
          "name": "vc_user_agent",
          "type": "varchar(800)",
          "nullable": true,
          "description": "Header user-agent do request."
        },
        {
          "name": "vc_app_version",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Versão do app informada em session_context."
        },
        {
          "name": "dh_access",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora do acesso."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "screen",
      "title": "Tela do app",
      "description": "Catálogo GLOBAL das telas do app (não depende de empresa). O uuid é a chave da permissão e é o mesmo em todos os ambientes (seed com uuids fixos); o código é usado pelo app para rotear e o nome é o que aparece para o usuário. DASHBOARD é implícita para todo usuário logado.",
      "rls": "SELECT: qualquer usuário logado (telas ativas). Escrita só por migration/seed.",
      "columns": [
        {
          "name": "uu_screen",
          "type": "uuid",
          "pk": 1,
          "nullable": false,
          "default": "gen_random_uuid()",
          "description": "Id da tela. É a chave usada em access_profile_screen e event_log."
        },
        {
          "name": "vc_code",
          "type": "varchar(30)",
          "nullable": false,
          "description": "Código estável da tela (DASHBOARD, USERS, PROFILES, LOGS). Único; usado pelo app para rotear."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome bonito da tela, mostrado ao usuário."
        },
        {
          "name": "vc_group",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Agrupamento no menu (ex.: Administração)."
        },
        {
          "name": "nr_order",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Ordem no menu."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da tela.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "access_profile_screen",
      "title": "Permissão do perfil por tela",
      "description": "Linha existe = o perfil pode LER a tela; id_create e id_update liberam criar e alterar. Perfil de nível 100 (administrador) ignora esta tabela: tem tudo. Substituída inteira por access_profile_save (screens).",
      "rls": "SELECT: usuários da empresa. Escrita só via access_profile_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "access_profile.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_profile",
          "type": "bigint",
          "pk": 2,
          "fk": "access_profile.nr_profile",
          "nullable": false,
          "description": "Perfil de acesso."
        },
        {
          "name": "uu_screen",
          "type": "uuid",
          "pk": 3,
          "fk": "screen.uu_screen",
          "nullable": false,
          "description": "Tela liberada."
        },
        {
          "name": "id_read",
          "type": "boolean",
          "nullable": false,
          "default": "true",
          "description": "Pode ler (sempre verdadeiro quando a linha existe; check impede criar/alterar sem ler)."
        },
        {
          "name": "id_create",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Pode criar registros na tela."
        },
        {
          "name": "id_update",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Pode alterar registros na tela."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "event_log",
      "title": "Log de atividades",
      "description": "O que aconteceu no sistema: quem, quando, em qual tela, qual ação, qual registro, resumo legível e detalhe em JSON (nunca senhas). Gravado pelas RPCs via ad.fn_event_log; o app nunca escreve. Login/acesso fica em access_log.",
      "rls": "SELECT: os próprios eventos. A tela de logs usa event_log_list (admin vê a empresa).",
      "columns": [
        {
          "name": "nr_event",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Número do evento."
        },
        {
          "name": "nr_company",
          "type": "bigint",
          "nullable": true,
          "description": "Empresa do contexto."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "nullable": true,
          "description": "Filial aberta no app quando a ação foi feita (p_json.nr_branch)."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Quem fez."
        },
        {
          "name": "uu_screen",
          "type": "uuid",
          "fk": "screen.uu_screen",
          "nullable": true,
          "description": "Tela em que a ação aconteceu (nula para ações sem tela, ex.: empresa/filial)."
        },
        {
          "name": "vc_action",
          "type": "varchar(20)",
          "nullable": false,
          "description": "Tipo da ação.",
          "values": {
            "CREATE": "Criação",
            "UPDATE": "Alteração",
            "DELETE": "Exclusão",
            "OTHER": "Outra"
          }
        },
        {
          "name": "vc_entity",
          "type": "varchar(40)",
          "nullable": false,
          "description": "Entidade afetada (access_profile, company_user, branch, company, app_user)."
        },
        {
          "name": "vc_key",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Chave do registro em texto (ex.: 1/3)."
        },
        {
          "name": "vc_summary",
          "type": "varchar(200)",
          "nullable": false,
          "description": "Resumo legível (ex.: Perfil Recepção criado)."
        },
        {
          "name": "js_detail",
          "type": "jsonb",
          "nullable": true,
          "description": "Detalhe da ação (campos enviados), sem dados sensíveis."
        },
        {
          "name": "dh_event",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora do evento."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "pricing_param",
      "title": "Parâmetros de precificação",
      "description": "Parâmetros de precificação da filial: estrutura (salas, horas, ocupação), hora clínica do profissional, taxa de cartão, comissão padrão, regime do imposto de renda (PF/PJ) e lucro desejado. Uma linha por filial, criada no primeiro salvamento (pricing_param_save); antes disso pricing_param_get devolve os padrões sugeridos. Percentuais em pontos percentuais (4 = 4%).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via pricing_param_save (permissão na tela PRICING).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "qt_rooms",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Salas (cadeiras) em uso na filial."
        },
        {
          "name": "qt_hours_week",
          "type": "numeric(6,2)",
          "nullable": false,
          "default": "40",
          "description": "Horas de atendimento por semana, por sala."
        },
        {
          "name": "qt_weeks_month",
          "type": "numeric(4,2)",
          "nullable": false,
          "default": "4.33",
          "description": "Semanas por mês (4,33 = 52 ÷ 12)."
        },
        {
          "name": "pc_occupancy",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "70",
          "description": "Taxa de ocupação da agenda (%): parte das horas abertas que realmente vira atendimento. Horas produtivas = horas abertas × ocupação."
        },
        {
          "name": "vl_professional_hour",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Hora clínica do profissional (R$/h): remuneração do dentista por hora de cadeira, entra no custo direto."
        },
        {
          "name": "pc_card",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "4",
          "description": "Taxa média da máquina de cartão (% sobre o preço; média de débito/crédito/parcelado)."
        },
        {
          "name": "pc_commission",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Comissão padrão (% sobre o preço), ex.: recepção/captação. Cada procedimento pode ter a sua própria (procedure.pc_commission)."
        },
        {
          "name": "it_tax_regime",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Regime do imposto de renda usado no preço.",
          "values": {
            "1": "Pessoa física (IR sobre o lucro, carnê-leão)",
            "2": "Pessoa jurídica (tributos sobre o faturamento)"
          }
        },
        {
          "name": "pc_tax_pf",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "27.5",
          "description": "Imposto de renda pessoa física (%): incide sobre o lucro do procedimento (receita − custos − taxas). Padrão 27,5% = faixa máxima do carnê-leão; use a alíquota efetiva."
        },
        {
          "name": "pc_tax_pj",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "11.33",
          "description": "Tributos pessoa jurídica (%): alíquota efetiva do regime sobre o faturamento (Simples Nacional: 6% a 15,5%; Lucro Presumido: 11,33% + ISS). Padrão 11,33%."
        },
        {
          "name": "pc_profit",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "30",
          "description": "Lucro desejado padrão (% sobre o preço). Cada procedimento pode ter o seu próprio (procedure.pc_profit)."
        },
        {
          "name": "vl_structure_hour_manual",
          "type": "numeric(12,2)",
          "nullable": true,
          "description": "Custo da estrutura por hora informado manualmente (R$/h). Quando preenchido substitui o cálculo (custo mensal ÷ horas produtivas), como a planilha original que digitava R$ 30 sobre os R$ 30,36 calculados. Nulo = usa o cálculo."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "clinic_expense",
      "title": "Despesa da clínica",
      "description": "Despesas que formam o custo mensal da clínica (custo da estrutura): fixas mensais, variáveis mensais, eventuais anuais (divididas por 12) e publicidade mensal. Custo da estrutura por hora = custo mensal ÷ horas produtivas. A lista inteira é substituída a cada pricing_param_save.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via pricing_param_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_expense",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da despesa na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome da despesa (Aluguel, Energia, Salários...)."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo da despesa.",
          "values": {
            "1": "Fixa mensal",
            "2": "Variável mensal",
            "3": "Eventual anual (÷ 12 no custo mensal)",
            "4": "Publicidade mensal"
          }
        },
        {
          "name": "vl_amount",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Valor (mensal, ou anual quando it_type = 3)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da despesa.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "pricing_fee",
      "title": "Taxa adicional de precificação",
      "description": "Taxas adicionais sobre o preço que a clínica liga ou desliga por filial (ISS, inadimplência, antecipação de recebíveis, garantia/retrabalho, margem de negociação, convênios...). Só as ativas entram no cálculo (somadas aos percentuais sobre o preço). pricing_param_get sugere uma lista inicial; a lista inteira é substituída a cada pricing_param_save.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via pricing_param_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_fee",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da taxa na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome da taxa (ISS, Inadimplência...)."
        },
        {
          "name": "vc_hint",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Explicação curta mostrada na tela (quando usar, faixa típica)."
        },
        {
          "name": "pc_rate",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Percentual sobre o preço (pontos percentuais)."
        },
        {
          "name": "id_active",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Entra no cálculo do preço?"
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "material",
      "title": "Material",
      "description": "Catálogo de materiais da filial. Custo por unidade de uso = preço da embalagem ÷ (rendimento × (1 − perda)). O preço pode ser digitado ou vir da pesquisa de mercado (Edge Function material-price-lookup), com a loja/URL de origem e a data da última atualização.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via material_save (permissão na tela PRICING).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_material",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do material na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "uk": "material_vc_name_uk",
          "nullable": false,
          "description": "Nome do material (único na filial, sem diferenciar maiúsculas)."
        },
        {
          "name": "vc_package",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Embalagem comprada (ex.: Caixa 100, Seringa 4 g)."
        },
        {
          "name": "vl_package_price",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Preço da embalagem (R$)."
        },
        {
          "name": "qt_yield",
          "type": "numeric(10,3)",
          "nullable": false,
          "default": "1",
          "description": "Rendimento: quantas unidades de uso a embalagem rende (ex.: caixa com 100 luvas = 100; seringa de 4 g usada 0,1 g por vez = 40)."
        },
        {
          "name": "vc_unit",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Unidade de uso (unidade, par, g, ml, aplicação...)."
        },
        {
          "name": "pc_waste",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Perda / desperdício (%), reduz o rendimento efetivo."
        },
        {
          "name": "it_price_source",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Origem do preço.",
          "values": {
            "1": "Manual (digitado)",
            "2": "Pesquisa de mercado (Edge Function material-price-lookup)"
          }
        },
        {
          "name": "vc_price_source",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Loja / URL de onde o preço veio."
        },
        {
          "name": "dh_price_updated",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora da última atualização de preço, rendimento ou perda."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do material.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "specialty",
      "title": "Especialidade",
      "description": "Especialidade da filial (Clínica Geral, Implante, Ortodontia, HOF, Endodontia, Prótese...): agrupa os procedimentos na aba Especialidades da tela Precificação e define o lucro desejado deles. Lucro usado no preço: procedimento > especialidade > filial. nr_specialty é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via specialty_save (permissão na tela PRICING).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_specialty",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da especialidade na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(40)",
          "uk": "specialty_vc_name_uk",
          "nullable": false,
          "description": "Nome da especialidade (único na filial, sem diferenciar maiúsculas)."
        },
        {
          "name": "pc_profit",
          "type": "numeric(5,2)",
          "nullable": true,
          "description": "Lucro desejado da especialidade (% sobre o preço) para os procedimentos sem lucro próprio. Nulo = usa pricing_param.pc_profit."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da especialidade (inativa some da lista; os procedimentos continuam ligados).",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "procedure_template",
      "title": "Catálogo de procedimentos (referência)",
      "description": "Catálogo GLOBAL de procedimentos por especialidade, com os dados da planilha de precificação da clínica (código, nome, tempo, material informado, laboratório e valor de referência). Alimenta o auto complete do cadastro de procedimento (procedure_suggest), que sugere o que a filial ainda não cadastrou. A especialidade é casada pelo nome com od.specialty. Mantido só por migration.",
      "rls": "Ligada e sem policy: leitura só pela RPC procedure_suggest (SECURITY DEFINER); escrita só por migration.",
      "columns": [
        {
          "name": "nr_template",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Identificador do item do catálogo."
        },
        {
          "name": "vc_specialty",
          "type": "varchar(40)",
          "uk": "procedure_template_name_uk",
          "nullable": false,
          "description": "Nome da especialidade (Clínica Geral, Endodontia, Implante, Ortodontia, HOF...), casado sem diferenciar maiúsculas com od.specialty.vc_name."
        },
        {
          "name": "vc_code",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Código da tabela da planilha (ex.: 3.1). Vai nulo na sugestão quando a filial já usa o código."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "uk": "procedure_template_name_uk",
          "nullable": false,
          "description": "Nome do procedimento (único por especialidade)."
        },
        {
          "name": "qt_minutes",
          "type": "numeric(7,2)",
          "nullable": false,
          "default": "0",
          "description": "Tempo de cadeira sugerido, em minutos."
        },
        {
          "name": "vl_material_other",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Custo de material informado na planilha (R$), sugerido como \"outros materiais\"."
        },
        {
          "name": "vl_lab_cost",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Laboratório / terceiros sugerido (R$)."
        },
        {
          "name": "vl_reference_price",
          "type": "numeric(12,2)",
          "nullable": true,
          "description": "Valor cobrado na planilha (R$), sugerido como valor cobrado hoje."
        },
        {
          "name": "nr_order",
          "type": "integer",
          "nullable": false,
          "default": "0",
          "description": "Ordem de exibição (a da planilha)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do item do catálogo.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "procedure",
      "title": "Procedimento",
      "description": "Procedimento precificado, ligado a uma especialidade: tempo de cadeira, laboratório/terceiros, outros materiais (valor informado), valor cobrado hoje (comparado ao custo, ao preço mínimo e ao sugerido para gerar o alerta) e, opcionalmente, comissão e lucro próprios. O preço não é gravado: procedure_list calcula sempre com os parâmetros atuais (od.fn_pricing_calc).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via procedure_save (permissão na tela PRICING).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do procedimento na filial."
        },
        {
          "name": "vc_code",
          "type": "varchar(10)",
          "uk": "procedure_vc_code_uk",
          "nullable": true,
          "description": "Código da tabela da clínica (ex.: 3.1). Único na filial quando informado."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "uk": "procedure_vc_name_uk",
          "nullable": false,
          "description": "Nome do procedimento (único na filial)."
        },
        {
          "name": "nr_specialty",
          "type": "bigint",
          "fk": "specialty.nr_specialty",
          "nullable": true,
          "description": "Especialidade do procedimento (od.specialty). Nula = sem especialidade."
        },
        {
          "name": "qt_minutes",
          "type": "numeric(7,2)",
          "nullable": false,
          "default": "0",
          "description": "Tempo de cadeira em minutos: define o custo da estrutura e a hora clínica do profissional."
        },
        {
          "name": "vl_lab_cost",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Laboratório / terceiros (R$), entra no custo direto."
        },
        {
          "name": "vl_material_other",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Outros materiais (R$ informado), somado aos materiais cadastrados."
        },
        {
          "name": "vl_current_price",
          "type": "numeric(12,2)",
          "nullable": true,
          "description": "Valor cobrado hoje (R$), só para comparar com o preço sugerido."
        },
        {
          "name": "pc_commission",
          "type": "numeric(5,2)",
          "nullable": true,
          "description": "Comissão própria (% sobre o preço). Nula = usa pricing_param.pc_commission."
        },
        {
          "name": "pc_profit",
          "type": "numeric(5,2)",
          "nullable": true,
          "description": "Lucro desejado próprio (% sobre o preço). Nulo = usa o lucro da especialidade e, se ela também não tiver, pricing_param.pc_profit."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do procedimento.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "procedure_material",
      "title": "Material do procedimento",
      "description": "Materiais usados em cada procedimento com a quantidade em unidades de uso. Custo da linha = quantidade × custo unitário do material. A lista é substituída a cada procedure_save com materials.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via procedure_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "procedure.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "procedure.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "pk": 3,
          "fk": "procedure.nr_procedure",
          "nullable": false,
          "description": "Procedimento."
        },
        {
          "name": "nr_material",
          "type": "bigint",
          "pk": 4,
          "fk": "material.nr_material",
          "nullable": false,
          "description": "Material usado."
        },
        {
          "name": "qt_used",
          "type": "numeric(10,3)",
          "nullable": false,
          "default": "1",
          "description": "Quantidade usada, em unidades de uso do material (> 0)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "professional",
      "title": "Profissional da agenda",
      "description": "Quem atende na filial (dentista, HOF, ASB...): uma coluna na agenda, com cor própria, intervalo dos horários e, opcionalmente, o usuário do sistema que é este profissional. nr_professional é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via professional_save (permissão na tela AGENDA).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do profissional na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "uk": "professional_vc_name_uk",
          "nullable": false,
          "description": "Nome exibido na agenda (único na filial)."
        },
        {
          "name": "vc_council",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Registro no conselho (ex.: CRO-PR 12345)."
        },
        {
          "name": "vc_color",
          "type": "varchar(7)",
          "nullable": false,
          "description": "Cor da coluna na agenda, #RRGGBB em maiúsculas (sem cor na criação: próxima da paleta padrão)."
        },
        {
          "name": "qt_slot_minutes",
          "type": "smallint",
          "nullable": false,
          "default": "30",
          "description": "Intervalo dos horários na agenda deste profissional, em minutos (5 a 240)."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "uk": "professional_nr_user_uk",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Usuário do sistema que é este profissional (ativo na empresa; no máximo um profissional por usuário na filial)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do profissional (inativo some da agenda).",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "professional_schedule",
      "title": "Horário de atendimento",
      "description": "Faixas de atendimento do profissional por dia da semana (várias por dia, sem sobrepor). Fora delas a agenda mostra o horário como indisponível. Substituído inteiro a cada professional_save com schedules.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via professional_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "professional.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "professional.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "pk": 3,
          "fk": "professional.nr_professional",
          "nullable": false,
          "description": "Profissional."
        },
        {
          "name": "nr_schedule",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número da faixa no profissional (renumerado a cada gravação, por dia e hora)."
        },
        {
          "name": "it_weekday",
          "type": "smallint",
          "nullable": false,
          "description": "Dia da semana.",
          "values": {
            "0": "Domingo",
            "1": "Segunda",
            "2": "Terça",
            "3": "Quarta",
            "4": "Quinta",
            "5": "Sexta",
            "6": "Sábado"
          }
        },
        {
          "name": "qt_minute_start",
          "type": "smallint",
          "nullable": false,
          "description": "Início da faixa, em minutos desde a meia-noite (480 = 08:00)."
        },
        {
          "name": "qt_minute_end",
          "type": "smallint",
          "nullable": false,
          "description": "Fim da faixa, em minutos desde a meia-noite (maior que o início; até 1440)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "appointment",
      "title": "Agendamento",
      "description": "Um horário na agenda da filial: consulta (paciente + profissional, procedimento opcional) ou compromisso (bloqueio com título, de um profissional ou da clínica toda), com a situação do atendimento. Datas com fuso; a agenda é lida no fuso da filial. Conflito de horário checado em appointment_save (encaixe libera). nr_appointment é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via appointment_save (permissão na tela AGENDA).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_appointment",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do agendamento na filial."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo do agendamento.",
          "values": {
            "1": "Consulta",
            "2": "Compromisso"
          }
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "fk": "patient.nr_patient",
          "nullable": true,
          "description": "Paciente da consulta (obrigatório na consulta; nulo no compromisso)."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional (obrigatório na consulta; no compromisso, nulo = clínica toda)."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "fk": "procedure.nr_procedure",
          "nullable": true,
          "description": "Procedimento previsto (opcional, da precificação)."
        },
        {
          "name": "vc_title",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Título do compromisso (obrigatório) ou motivo da consulta (opcional)."
        },
        {
          "name": "vc_notes",
          "type": "text",
          "nullable": true,
          "description": "Observações do agendamento."
        },
        {
          "name": "dh_start",
          "type": "timestamptz",
          "nullable": false,
          "description": "Início."
        },
        {
          "name": "dh_end",
          "type": "timestamptz",
          "nullable": false,
          "description": "Fim (maior que o início; no máximo 1 dia depois)."
        },
        {
          "name": "id_all_day",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Compromisso do dia inteiro."
        },
        {
          "name": "id_fit_in",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Encaixe: pode se sobrepor a outro agendamento do mesmo profissional."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do atendimento (cancelado e faltou não ocupam o horário).",
          "values": {
            "1": "Agendado",
            "2": "Confirmado",
            "3": "Em espera",
            "4": "Em atendimento",
            "5": "Atendido",
            "6": "Atrasado",
            "7": "Faltou",
            "90": "Cancelado"
          }
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem agendou (usuário da sessão na criação)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_account",
      "title": "Conta financeira",
      "description": "Conta onde o dinheiro entra e sai na filial (caixa, banco, cofre), com saldo inicial. Saldo = saldo inicial + receitas pagas − despesas pagas (od.fn_fin_balance). nr_account é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_account_save e fin_setup (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da conta na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "uk": "fin_account_vc_name_uk",
          "nullable": false,
          "description": "Nome da conta (único na filial)."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo da conta (4 é a conta de passagem criada pelo sistema para cartão/boleto/cheque até o dinheiro cair).",
          "values": {
            "1": "Caixa",
            "2": "Banco",
            "3": "Cofre",
            "4": "Recebíveis"
          }
        },
        {
          "name": "vl_opening",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Saldo inicial (R$; pode ser negativo)."
        },
        {
          "name": "vc_bank_code",
          "type": "varchar(3)",
          "nullable": true,
          "description": "Código do banco (3 dígitos, ex.: 001)."
        },
        {
          "name": "vc_bank_name",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Nome do banco."
        },
        {
          "name": "vc_agency",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Agência."
        },
        {
          "name": "vc_account_number",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Número da conta (com dígito)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da conta.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_category",
      "title": "Categoria financeira (plano de contas)",
      "description": "Plano de contas da filial: categorias de receita e de despesa. A despesa tem o tipo de custo (fixo, variável, investimento, outros), como as despesas da precificação, de onde fin_setup cria as primeiras. nr_category é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_category_save e fin_setup (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_category",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da categoria na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "uk": "fin_category_vc_name_uk",
          "nullable": false,
          "description": "Nome da categoria (único por tipo na filial)."
        },
        {
          "name": "it_kind",
          "type": "smallint",
          "nullable": false,
          "description": "Receita ou despesa (não muda depois de criada).",
          "values": {
            "1": "Receita",
            "2": "Despesa"
          }
        },
        {
          "name": "it_cost_type",
          "type": "smallint",
          "nullable": true,
          "description": "Tipo de custo da despesa (nulo na receita).",
          "values": {
            "1": "Custo fixo",
            "2": "Custo variável",
            "3": "Investimento",
            "4": "Outros"
          }
        },
        {
          "name": "it_dre_group",
          "type": "smallint",
          "nullable": true,
          "description": "Grupo da categoria no DRE (nulo = automático pelo tipo).",
          "values": {
            "1": "Receita operacional",
            "2": "Dedução da receita",
            "3": "Custo variável",
            "4": "Custo fixo",
            "5": "Despesa operacional",
            "6": "Receita não operacional",
            "7": "Despesa não operacional",
            "8": "Investimento (fora do resultado)"
          }
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da categoria.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_supplier",
      "title": "Fornecedor",
      "description": "Fornecedores da filial, usados nas contas a pagar. CPF/CNPJ e telefone só com dígitos. nr_supplier é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_supplier_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_supplier",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do fornecedor na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(120)",
          "uk": "fin_supplier_vc_name_uk",
          "nullable": false,
          "description": "Nome / razão social (único na filial)."
        },
        {
          "name": "vc_document",
          "type": "varchar(14)",
          "nullable": true,
          "description": "CPF (11, validado) ou CNPJ (14, alfanumérico ok), só dígitos/letras."
        },
        {
          "name": "vc_phone",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Telefone, só dígitos (DDD + número)."
        },
        {
          "name": "vc_email",
          "type": "varchar(120)",
          "nullable": true,
          "description": "E-mail em minúsculas."
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do fornecedor.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_entry",
      "title": "Lançamento financeiro",
      "description": "Conta a receber ou a pagar da filial: categoria, conta, fornecedor ou paciente, descrição, valor, vencimento, competência, forma de pagamento, pagamento (data e valor) e situação. Parcelas e repetições mensais ficam ligadas pelo mesmo uu_group. nr_entry é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_entry_save, fin_entry_settle e appointment_checkout (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do lançamento na filial."
        },
        {
          "name": "it_kind",
          "type": "smallint",
          "nullable": false,
          "description": "A receber ou a pagar.",
          "values": {
            "1": "A receber (receita)",
            "2": "A pagar (despesa)"
          }
        },
        {
          "name": "nr_category",
          "type": "bigint",
          "fk": "fin_category.nr_category",
          "nullable": false,
          "description": "Categoria do plano de contas (do mesmo tipo)."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": true,
          "description": "Conta (obrigatória quando pago)."
        },
        {
          "name": "nr_supplier",
          "type": "bigint",
          "fk": "fin_supplier.nr_supplier",
          "nullable": true,
          "description": "Fornecedor (contas a pagar)."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "fk": "patient.nr_patient",
          "nullable": true,
          "description": "Paciente (contas a receber)."
        },
        {
          "name": "vc_description",
          "type": "varchar(140)",
          "nullable": false,
          "description": "Descrição (parcelas ganham \" (n/N)\")."
        },
        {
          "name": "vl_amount",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor (R$, > 0)."
        },
        {
          "name": "dt_due",
          "type": "date",
          "nullable": false,
          "description": "Vencimento."
        },
        {
          "name": "dt_competence",
          "type": "date",
          "nullable": false,
          "description": "Competência (mês a que o valor se refere; padrão = vencimento)."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": true,
          "description": "Forma de pagamento.",
          "values": {
            "1": "Dinheiro",
            "2": "Pix",
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "5": "Transferência",
            "6": "Boleto",
            "7": "Cheque",
            "9": "Outro"
          }
        },
        {
          "name": "dt_paid",
          "type": "date",
          "nullable": true,
          "description": "Data do pagamento (só quando pago)."
        },
        {
          "name": "vl_paid",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Valor pago (só quando pago; entra no saldo da conta)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação (vencido = em aberto com vencimento antes de hoje).",
          "values": {
            "1": "Em aberto",
            "2": "Pago",
            "90": "Cancelado"
          }
        },
        {
          "name": "uu_group",
          "type": "uuid",
          "nullable": true,
          "description": "Liga as parcelas / repetições criadas juntas."
        },
        {
          "name": "nr_installment",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Número da parcela / repetição."
        },
        {
          "name": "qt_installments",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Total de parcelas / repetições do grupo."
        },
        {
          "name": "id_recurring",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Conta recorrente (mesmo valor todo mês) em vez de parcelada."
        },
        {
          "name": "nr_recurrence",
          "type": "bigint",
          "fk": "fin_recurrence.nr_recurrence",
          "nullable": true,
          "description": "Conta recorrente (regra) que gerou o lançamento."
        },
        {
          "name": "dh_health_exported",
          "type": "timestamptz",
          "nullable": true,
          "description": "Quando o recebimento foi exportado para a Receita Saúde (nulo = ainda não)."
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem lançou."
        },
        {
          "name": "nr_appointment",
          "type": "bigint",
          "fk": "appointment.nr_appointment",
          "nullable": true,
          "description": "Atendimento da agenda que gerou o lançamento (fechamento da consulta: recebimento e comissão)."
        },
        {
          "name": "nr_budget",
          "type": "bigint",
          "fk": "budget.nr_budget",
          "nullable": true,
          "description": "Orçamento aprovado que gerou a conta a receber."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional (comissão a pagar ou atendimento a receber)."
        },
        {
          "name": "nr_cash_session",
          "type": "bigint",
          "fk": "fin_cash_session.nr_session",
          "nullable": true,
          "description": "Sessão de caixa em que o pagamento entrou (conta com caixa aberto no momento da baixa)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "budget",
      "title": "Orçamento",
      "description": "Orçamento (plano de tratamento) do paciente: itens, desconto, validade e condição de pagamento. Desconto acima do máximo da filial fica aguardando o administrador; aprovado pelo paciente gera as contas a receber (fin_entry.nr_budget). nr_budget é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via budget_save e budget_status (tela BUDGETS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_budget",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do orçamento na filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional responsável."
        },
        {
          "name": "vc_title",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Título (ex. Reabilitação superior)."
        },
        {
          "name": "dt_budget",
          "type": "date",
          "nullable": false,
          "description": "Data do orçamento."
        },
        {
          "name": "dt_valid",
          "type": "date",
          "nullable": false,
          "description": "Validade (padrão: data + qt_budget_valid_days)."
        },
        {
          "name": "vl_gross",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Soma dos itens."
        },
        {
          "name": "vl_discount",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Desconto em valor."
        },
        {
          "name": "vl_total",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Total (bruto − desconto)."
        },
        {
          "name": "qt_installments",
          "type": "smallint",
          "nullable": true,
          "description": "Condição de pagamento: parcelas (1 a 24)."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": true,
          "description": "Forma de pagamento prevista.",
          "values": {
            "1": "Dinheiro",
            "2": "Pix",
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "5": "Transferência",
            "6": "Boleto",
            "7": "Cheque",
            "9": "Outro"
          }
        },
        {
          "name": "vc_notes",
          "type": "varchar(1000)",
          "nullable": true,
          "description": "Observações."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do orçamento.",
          "values": {
            "1": "Em aberto",
            "2": "Aguardando aprovação do desconto",
            "3": "Aprovado pelo paciente",
            "4": "Recusado",
            "90": "Cancelado"
          }
        },
        {
          "name": "id_discount_approved",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Desconto acima do máximo aprovado pelo administrador."
        },
        {
          "name": "id_below_min",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Algum item ficou abaixo do preço mínimo da precificação (com o desconto rateado)."
        },
        {
          "name": "nr_user_discount",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Administrador que aprovou o desconto."
        },
        {
          "name": "dh_discount",
          "type": "timestamptz",
          "nullable": true,
          "description": "Quando o desconto foi aprovado."
        },
        {
          "name": "dh_accepted",
          "type": "timestamptz",
          "nullable": true,
          "description": "Quando o paciente aprovou (gerou as contas a receber)."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Usuário que criou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "budget_item",
      "title": "Item do orçamento",
      "description": "Procedimento (ou item livre) do orçamento com dente/região, quantidade e valores.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via budget_save (tela BUDGETS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "budget.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "budget.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_budget",
          "type": "bigint",
          "pk": 3,
          "fk": "budget.nr_budget",
          "nullable": false,
          "description": "Orçamento."
        },
        {
          "name": "nr_item",
          "type": "smallint",
          "pk": 4,
          "nullable": false,
          "description": "Ordem do item no orçamento."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "fk": "procedure.nr_procedure",
          "nullable": true,
          "description": "Procedimento da precificação (nulo = item livre)."
        },
        {
          "name": "vc_description",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Descrição (padrão: nome do procedimento)."
        },
        {
          "name": "vc_tooth",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Dente ou região."
        },
        {
          "name": "qt_quantity",
          "type": "numeric(7,2)",
          "nullable": false,
          "default": "1",
          "description": "Quantidade."
        },
        {
          "name": "vl_unit",
          "type": "numeric(12,2)",
          "nullable": false,
          "default": "0",
          "description": "Valor unitário (padrão: valor cobrado hoje do procedimento)."
        },
        {
          "name": "vl_total",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Quantidade × valor unitário."
        },
        {
          "name": "dt_done",
          "type": "date",
          "nullable": true,
          "description": "Data em que o item foi realizado (evolução clínica ligada); nulo = a fazer."
        },
        {
          "name": "nr_evolution",
          "type": "bigint",
          "nullable": true,
          "description": "Evolução clínica (clinical_evolution.nr_evolution do paciente) que registrou a realização."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "anamnesis_model",
      "title": "Modelo de anamnese",
      "description": "Modelo (questionário) de anamnese da filial, opcionalmente de uma especialidade. O modelo \"Geral\" com as perguntas usuais é criado na primeira consulta (od.fn_anamnesis_default). nr_model é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via anamnesis_model_save (tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_model",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do modelo na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "nullable": false,
          "description": "Nome do modelo (ex. Geral, Ortodontia)."
        },
        {
          "name": "nr_specialty",
          "type": "bigint",
          "fk": "specialty.nr_specialty",
          "nullable": true,
          "description": "Especialidade a que o modelo se destina (nulo = qualquer)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do modelo.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "anamnesis_question",
      "title": "Pergunta do modelo de anamnese",
      "description": "Perguntas do modelo, na ordem de nr_question. id_alert: resposta \"sim\" vira alerta no prontuário. Substituídas inteiras a cada alteração do modelo (as anamneses preenchidas guardam a própria cópia).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via anamnesis_model_save (tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "anamnesis_model.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "anamnesis_model.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_model",
          "type": "bigint",
          "pk": 3,
          "fk": "anamnesis_model.nr_model",
          "nullable": false,
          "description": "Modelo."
        },
        {
          "name": "nr_question",
          "type": "smallint",
          "pk": 4,
          "nullable": false,
          "description": "Ordem da pergunta."
        },
        {
          "name": "vc_question",
          "type": "varchar(200)",
          "nullable": false,
          "description": "Texto da pergunta."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo de resposta.",
          "values": {
            "1": "Sim/não",
            "2": "Texto livre",
            "3": "Sim/não com detalhe"
          }
        },
        {
          "name": "id_alert",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Resposta \"sim\" gera alerta no prontuário (não vale para texto livre)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient_anamnesis",
      "title": "Anamnese do paciente",
      "description": "Anamnese preenchida do paciente a partir de um modelo, com cópia do nome do modelo e das perguntas para o histórico não mudar. A mais recente define os alertas do prontuário. Exclusão lógica.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_anamnesis_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_anamnesis",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número sequencial da anamnese do paciente."
        },
        {
          "name": "nr_model",
          "type": "bigint",
          "fk": "anamnesis_model.nr_model",
          "nullable": true,
          "description": "Modelo usado."
        },
        {
          "name": "vc_model",
          "type": "varchar(80)",
          "nullable": false,
          "description": "Nome do modelo no momento do preenchimento."
        },
        {
          "name": "dt_filled",
          "type": "date",
          "nullable": false,
          "description": "Data do preenchimento (não pode ser futura)."
        },
        {
          "name": "vc_notes",
          "type": "varchar(2000)",
          "nullable": true,
          "description": "Observações gerais."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Excluído"
          }
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que registrou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient_anamnesis_answer",
      "title": "Resposta da anamnese",
      "description": "Respostas da anamnese do paciente, com a cópia da pergunta e do tipo. id_alert marca a resposta \"sim\" de pergunta de alerta.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_anamnesis_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient_anamnesis.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient_anamnesis.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient_anamnesis.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_anamnesis",
          "type": "bigint",
          "pk": 4,
          "fk": "patient_anamnesis.nr_anamnesis",
          "nullable": false,
          "description": "Anamnese."
        },
        {
          "name": "nr_question",
          "type": "smallint",
          "pk": 5,
          "nullable": false,
          "description": "Ordem da pergunta."
        },
        {
          "name": "vc_question",
          "type": "varchar(200)",
          "nullable": false,
          "description": "Texto da pergunta no momento do preenchimento."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "description": "Tipo de resposta.",
          "values": {
            "1": "Sim/não",
            "2": "Texto livre",
            "3": "Sim/não com detalhe"
          }
        },
        {
          "name": "id_yes",
          "type": "boolean",
          "nullable": true,
          "description": "Resposta sim/não (nulo = não respondida ou texto livre)."
        },
        {
          "name": "vc_text",
          "type": "varchar(1000)",
          "nullable": true,
          "description": "Texto da resposta ou detalhe do \"sim\"."
        },
        {
          "name": "id_alert",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Resposta gera alerta no prontuário."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "clinical_evolution",
      "title": "Evolução clínica",
      "description": "Registro do atendimento no prontuário: texto, profissional, dente/região, procedimento e, quando ligado, o item de orçamento aprovado realizado (budget_item.dt_done). Não se altera depois de gravada; exclusão lógica desmarca o item. nr_evolution é sequencial por paciente.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via clinical_evolution_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_evolution",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número sequencial da evolução do paciente."
        },
        {
          "name": "dh_evolution",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data e hora do atendimento (não pode ser futura)."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional que atendeu."
        },
        {
          "name": "vc_text",
          "type": "varchar(4000)",
          "nullable": false,
          "description": "Descrição do atendimento."
        },
        {
          "name": "vc_tooth",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Dente ou região."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "fk": "procedure.nr_procedure",
          "nullable": true,
          "description": "Procedimento realizado (padrão: o do item do orçamento)."
        },
        {
          "name": "nr_budget",
          "type": "bigint",
          "fk": "budget_item.nr_budget",
          "nullable": true,
          "description": "Orçamento do item realizado."
        },
        {
          "name": "nr_item",
          "type": "smallint",
          "fk": "budget_item.nr_item",
          "nullable": true,
          "description": "Item do orçamento realizado."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Excluído"
          }
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que registrou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "tooth_mark",
      "title": "Marcação do odontograma",
      "description": "Odontograma do paciente: uma linha por marcação de dente (numeração FDI: 11 a 48 permanentes, 51 a 85 decíduos), condição, faces e situação (existente, a tratar, realizado). Exclusão lógica.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via tooth_mark_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_mark",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número sequencial da marcação do paciente."
        },
        {
          "name": "vc_tooth",
          "type": "varchar(2)",
          "nullable": false,
          "description": "Dente na numeração FDI (ex. 11, 36, 55)."
        },
        {
          "name": "it_condition",
          "type": "smallint",
          "nullable": false,
          "description": "Condição marcada.",
          "values": {
            "1": "Cárie",
            "2": "Restauração",
            "3": "Ausente/extraído",
            "4": "Implante",
            "5": "Coroa/prótese",
            "6": "Tratamento de canal",
            "7": "Extração indicada",
            "8": "Fratura",
            "9": "Selante",
            "10": "Outro"
          }
        },
        {
          "name": "vc_faces",
          "type": "varchar(5)",
          "nullable": true,
          "description": "Faces: M mesial, D distal, O oclusal, V vestibular, L lingual, I incisal, P palatina."
        },
        {
          "name": "it_situation",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da condição.",
          "values": {
            "1": "Existente",
            "2": "A tratar",
            "3": "Realizado"
          }
        },
        {
          "name": "vc_notes",
          "type": "varchar(300)",
          "nullable": true,
          "description": "Observação."
        },
        {
          "name": "dt_mark",
          "type": "date",
          "nullable": false,
          "description": "Data da marcação."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do registro.",
          "values": {
            "1": "Ativo",
            "90": "Excluído"
          }
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que registrou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "document_template",
      "title": "Modelo de documento",
      "description": "Modelo de documento da filial (atestado, receituário, contrato, declaração, termo) com campos {{...}} preenchidos na emissão por od.fn_document_render. Os modelos padrão são criados na primeira consulta (od.fn_document_default).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via document_template_save (tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_template",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do modelo na filial."
        },
        {
          "name": "it_kind",
          "type": "smallint",
          "nullable": false,
          "description": "Tipo de documento.",
          "values": {
            "1": "Atestado",
            "2": "Receituário",
            "3": "Contrato",
            "4": "Declaração de comparecimento",
            "9": "Outro (termo, orientação...)"
          }
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "nullable": false,
          "description": "Nome do modelo."
        },
        {
          "name": "vc_body",
          "type": "varchar(20000)",
          "nullable": false,
          "description": "Texto com os campos {{paciente}}, {{cpf}}, {{data_extenso}}, {{dias}}..."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "medication",
      "title": "Medicamento",
      "description": "Catálogo de medicamentos da filial para o receituário, com posologia de referência. A lista inicial dos usuais na odontologia é criada na primeira consulta (od.fn_medication_default).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via medication_save (tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_medication",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do medicamento na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Nome do medicamento (princípio ativo)."
        },
        {
          "name": "vc_presentation",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Apresentação (concentração e forma, ex. 500 mg comprimido)."
        },
        {
          "name": "vc_dosage",
          "type": "varchar(300)",
          "nullable": true,
          "description": "Posologia."
        },
        {
          "name": "vc_quantity",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Quantidade a dispensar (ex. 1 caixa, 21 cápsulas)."
        },
        {
          "name": "it_use",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Via de uso, agrupa o receituário.",
          "values": {
            "1": "Uso interno",
            "2": "Uso externo",
            "3": "Uso tópico"
          }
        },
        {
          "name": "id_controlled",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Medicamento de controle especial (receita própria)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient_document",
      "title": "Documento do paciente",
      "description": "Documento emitido para o paciente: título e texto final já preenchidos (o modelo pode mudar sem alterar o emitido), data e profissional; o PDF é gerado no app a partir daqui. Exclusão lógica.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_document_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_document",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número sequencial do documento do paciente."
        },
        {
          "name": "it_kind",
          "type": "smallint",
          "nullable": false,
          "description": "Tipo de documento.",
          "values": {
            "1": "Atestado",
            "2": "Receituário",
            "3": "Contrato",
            "4": "Declaração de comparecimento",
            "9": "Outro (termo, orientação...)"
          }
        },
        {
          "name": "nr_template",
          "type": "bigint",
          "fk": "document_template.nr_template",
          "nullable": true,
          "description": "Modelo usado."
        },
        {
          "name": "vc_title",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Título impresso."
        },
        {
          "name": "vc_body",
          "type": "varchar(20000)",
          "nullable": true,
          "description": "Texto final do documento (no receituário, o cabeçalho; os medicamentos ficam nos itens)."
        },
        {
          "name": "dt_document",
          "type": "date",
          "nullable": false,
          "description": "Data do documento."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional que assina."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Excluído"
          }
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que emitiu."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient_document_item",
      "title": "Medicamento do receituário",
      "description": "Medicamentos do receituário emitido, com cópia dos dados do catálogo (ou digitados).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_document_save (tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient_document.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient_document.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient_document.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_document",
          "type": "bigint",
          "pk": 4,
          "fk": "patient_document.nr_document",
          "nullable": false,
          "description": "Documento."
        },
        {
          "name": "nr_item",
          "type": "smallint",
          "pk": 5,
          "nullable": false,
          "description": "Ordem do medicamento."
        },
        {
          "name": "nr_medication",
          "type": "bigint",
          "fk": "medication.nr_medication",
          "nullable": true,
          "description": "Medicamento do catálogo (nulo = digitado)."
        },
        {
          "name": "vc_name",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Nome do medicamento (princípio ativo)."
        },
        {
          "name": "vc_presentation",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Apresentação (concentração e forma, ex. 500 mg comprimido)."
        },
        {
          "name": "vc_dosage",
          "type": "varchar(300)",
          "nullable": true,
          "description": "Posologia."
        },
        {
          "name": "vc_quantity",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Quantidade a dispensar (ex. 1 caixa, 21 cápsulas)."
        },
        {
          "name": "it_use",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Via de uso, agrupa o receituário.",
          "values": {
            "1": "Uso interno",
            "2": "Uso externo",
            "3": "Uso tópico"
          }
        },
        {
          "name": "id_controlled",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Medicamento de controle especial (receita própria)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_cash_session",
      "title": "Sessão de caixa",
      "description": "Caixa do dia por pessoa: abertura (valor contado) e fechamento (contado × esperado) numa conta do tipo caixa. Uma sessão aberta por conta e por usuário; recebimentos, pagamentos e transferências feitos na conta enquanto aberta entram no fechamento. nr_session é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_cash_open e fin_cash_close (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_session",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da sessão na filial."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta do tipo caixa."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Quem abriu (dono do caixa)."
        },
        {
          "name": "dh_open",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Abertura."
        },
        {
          "name": "vl_open",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Valor contado na abertura (padrão: saldo da conta)."
        },
        {
          "name": "dh_close",
          "type": "timestamptz",
          "nullable": true,
          "description": "Fechamento."
        },
        {
          "name": "vl_counted",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Valor contado no fechamento."
        },
        {
          "name": "vl_expected",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Saldo da conta no fechamento (esperado); diferença = contado − esperado."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Aberto",
            "2": "Fechado"
          }
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações."
        },
        {
          "name": "nr_user_closed",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem fechou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_transfer",
      "title": "Transferência entre contas",
      "description": "Dinheiro que passa de uma conta da filial para outra (não é receita nem despesa): transferência, sangria (do caixa para outra conta) ou suprimento (de outra conta para o caixa). Entra no saldo e no extrato das duas contas. nr_transfer é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_transfer_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_transfer",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial na filial."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo do movimento.",
          "values": {
            "1": "Transferência",
            "2": "Sangria",
            "3": "Suprimento"
          }
        },
        {
          "name": "nr_account_from",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta de origem."
        },
        {
          "name": "nr_account_to",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta de destino (diferente da origem)."
        },
        {
          "name": "vl_amount",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor (R$, > 0)."
        },
        {
          "name": "dt_transfer",
          "type": "date",
          "nullable": false,
          "description": "Data do movimento."
        },
        {
          "name": "vc_description",
          "type": "varchar(140)",
          "nullable": true,
          "description": "Descrição (padrão: o tipo)."
        },
        {
          "name": "nr_cash_session",
          "type": "bigint",
          "fk": "fin_cash_session.nr_session",
          "nullable": true,
          "description": "Sessão de caixa aberta na conta caixa envolvida."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativa",
            "90": "Cancelada"
          }
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem registrou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_card_rate",
      "title": "Taxa de recebimento",
      "description": "Taxa da filial por forma de pagamento (cartão de crédito, débito, boleto, cheque) e faixa de parcelas: percentual, tarifa fixa, prazo em dias para o dinheiro cair e a conta destino. Com taxa cadastrada, a baixa nessa forma gera recebíveis. nr_rate é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_rate_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_rate",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da taxa na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome (único na filial), ex.: Crédito 2 a 6x."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": false,
          "description": "Forma de pagamento.",
          "values": {
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "6": "Boleto",
            "7": "Cheque"
          }
        },
        {
          "name": "qt_installments_min",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Menor número de parcelas da faixa (só crédito parcela)."
        },
        {
          "name": "qt_installments_max",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Maior número de parcelas da faixa (até 24)."
        },
        {
          "name": "pc_fee",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Taxa percentual sobre cada parcela (pontos: 3 = 3%)."
        },
        {
          "name": "vl_fee_fixed",
          "type": "numeric(10,2)",
          "nullable": false,
          "default": "0",
          "description": "Tarifa fixa por recebimento (cobrada na 1ª parcela)."
        },
        {
          "name": "qt_days",
          "type": "smallint",
          "nullable": false,
          "default": "30",
          "description": "Dias para o dinheiro cair (cada parcela seguinte soma 30)."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta onde o dinheiro cai (não pode ser a de passagem)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_receivable",
      "title": "Recebível",
      "description": "Parcela a receber da operadora ou do banco depois de uma baixa em cartão, boleto ou cheque: bruto, taxa, líquido, previsão e conta destino. Enquanto não cai, o valor fica na conta de passagem Recebíveis; a confirmação transfere o recebido para a conta destino e lança a diferença como despesa (Taxas de recebimento). nr_receivable é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita pela baixa (fin_entry_settle, fin_entry_save, appointment_checkout) e por fin_receivable_settle (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_receivable",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do recebível na filial."
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": false,
          "description": "Conta a receber paga que gerou o recebível."
        },
        {
          "name": "nr_rate",
          "type": "bigint",
          "fk": "fin_card_rate.nr_rate",
          "nullable": true,
          "description": "Taxa aplicada."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": false,
          "description": "Forma de pagamento.",
          "values": {
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "6": "Boleto",
            "7": "Cheque"
          }
        },
        {
          "name": "nr_installment",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Parcela do cartão."
        },
        {
          "name": "qt_installments",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Total de parcelas do cartão."
        },
        {
          "name": "vl_gross",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor bruto da parcela."
        },
        {
          "name": "vl_fee",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Taxa prevista (percentual + tarifa fixa na 1ª)."
        },
        {
          "name": "vl_net",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Líquido previsto (bruto − taxa)."
        },
        {
          "name": "dt_expected",
          "type": "date",
          "nullable": false,
          "description": "Previsão de recebimento."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta destino."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação (vencido = a receber com previsão antes de hoje).",
          "values": {
            "1": "A receber",
            "2": "Recebido",
            "90": "Cancelado"
          }
        },
        {
          "name": "dt_received",
          "type": "date",
          "nullable": true,
          "description": "Data em que caiu (só recebido)."
        },
        {
          "name": "vl_received",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Valor que caiu (só recebido)."
        },
        {
          "name": "nr_transfer",
          "type": "bigint",
          "fk": "fin_transfer.nr_transfer",
          "nullable": true,
          "description": "Transferência da conta de passagem para a destino."
        },
        {
          "name": "nr_fee_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": true,
          "description": "Despesa da taxa lançada na confirmação."
        },
        {
          "name": "vc_reference",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Referência: NSU, número do cheque ou do boleto."
        },
        {
          "name": "vc_card_brand",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Bandeira do cartão (Visa, Mastercard, Elo...)."
        },
        {
          "name": "vc_card_last4",
          "type": "varchar(4)",
          "nullable": true,
          "description": "Últimos 4 dígitos do cartão."
        },
        {
          "name": "vc_authorization",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Código de autorização da venda no cartão."
        },
        {
          "name": "vc_holder_name",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Titular do cartão ou emitente do cheque."
        },
        {
          "name": "vc_holder_document",
          "type": "varchar(14)",
          "nullable": true,
          "description": "CPF ou CNPJ do titular/emitente (só dígitos)."
        },
        {
          "name": "vc_bank_name",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Banco do cheque."
        },
        {
          "name": "vc_check_number",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Número do cheque."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem fez a baixa."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "health_plan",
      "title": "Convênio",
      "description": "Convênio odontológico atendido pela filial: nome, registro ANS, CNPJ, prazo de repasse em dias e a conta onde o repasse cai. nr_plan é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via health_plan_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_plan",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do convênio na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(80)",
          "nullable": false,
          "description": "Nome (único na filial)."
        },
        {
          "name": "vc_ans",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Registro ANS da operadora (6 dígitos)."
        },
        {
          "name": "vc_document",
          "type": "varchar(14)",
          "nullable": true,
          "description": "CNPJ da operadora (só dígitos)."
        },
        {
          "name": "qt_payment_days",
          "type": "smallint",
          "nullable": false,
          "default": "30",
          "description": "Prazo de repasse em dias depois do faturamento."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": true,
          "description": "Conta onde o repasse cai."
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações (regras de envio, contato)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "health_plan_price",
      "title": "Tabela de preço do convênio",
      "description": "Valor que o convênio paga por procedimento (e o código da tabela do convênio). Preenche o valor dos itens da guia.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via health_plan_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_plan",
          "type": "bigint",
          "pk": 3,
          "fk": "health_plan.nr_plan",
          "nullable": false,
          "description": "Convênio."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "pk": 4,
          "fk": "procedure.nr_procedure",
          "nullable": false,
          "description": "Procedimento."
        },
        {
          "name": "vc_code",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Código do procedimento na tabela do convênio."
        },
        {
          "name": "vl_price",
          "type": "numeric(12,2)",
          "nullable": false,
          "description": "Valor pago pelo convênio (R$)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "health_guide",
      "title": "Guia de convênio",
      "description": "Guia de atendimento por convênio: paciente, profissional, carteirinha, número da guia, data, total dos itens e o ciclo aberta → faturada (gera a conta a receber do convênio) → paga (valor pago e glosa). nr_guide é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via health_guide_save e health_guide_settle (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_guide",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da guia na filial."
        },
        {
          "name": "nr_plan",
          "type": "bigint",
          "fk": "health_plan.nr_plan",
          "nullable": false,
          "description": "Convênio."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Paciente."
        },
        {
          "name": "nr_professional",
          "type": "bigint",
          "fk": "professional.nr_professional",
          "nullable": true,
          "description": "Profissional que atendeu."
        },
        {
          "name": "nr_appointment",
          "type": "bigint",
          "fk": "appointment.nr_appointment",
          "nullable": true,
          "description": "Atendimento da agenda (do mesmo paciente)."
        },
        {
          "name": "vc_guide_number",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Número da guia no convênio."
        },
        {
          "name": "vc_card_number",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Número da carteirinha do paciente."
        },
        {
          "name": "dt_service",
          "type": "date",
          "nullable": false,
          "description": "Data do atendimento."
        },
        {
          "name": "vl_total",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Total dos itens."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Aberta (a faturar)",
            "2": "Faturada",
            "3": "Paga",
            "90": "Cancelada"
          }
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": true,
          "description": "Conta a receber do faturamento (várias guias podem compartilhar)."
        },
        {
          "name": "dt_invoiced",
          "type": "date",
          "nullable": true,
          "description": "Data do faturamento."
        },
        {
          "name": "dt_paid",
          "type": "date",
          "nullable": true,
          "description": "Data do pagamento (só paga)."
        },
        {
          "name": "vl_paid",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Valor pago pelo convênio (só paga)."
        },
        {
          "name": "vl_denied",
          "type": "numeric(14,2)",
          "nullable": true,
          "description": "Glosa: total − pago (só paga)."
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem lançou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "health_guide_item",
      "title": "Item da guia",
      "description": "Procedimento da guia: dente/região, quantidade, valor unitário (da tabela do convênio ou informado), total e glosa do item.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via health_guide_save e health_guide_settle (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_guide",
          "type": "bigint",
          "pk": 3,
          "fk": "health_guide.nr_guide",
          "nullable": false,
          "description": "Guia."
        },
        {
          "name": "nr_item",
          "type": "smallint",
          "pk": 4,
          "nullable": false,
          "description": "Número do item na guia."
        },
        {
          "name": "nr_procedure",
          "type": "bigint",
          "fk": "procedure.nr_procedure",
          "nullable": false,
          "description": "Procedimento."
        },
        {
          "name": "vc_tooth",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Dente ou região."
        },
        {
          "name": "qt_quantity",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Quantidade (1 a 99)."
        },
        {
          "name": "vl_unit",
          "type": "numeric(12,2)",
          "nullable": false,
          "description": "Valor unitário."
        },
        {
          "name": "vl_total",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor unitário × quantidade."
        },
        {
          "name": "vl_denied",
          "type": "numeric(14,2)",
          "nullable": false,
          "default": "0",
          "description": "Glosa do item."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_bank_line",
      "title": "Linha do extrato bancário",
      "description": "Transação importada do arquivo OFX do banco para uma conta: id do banco (FITID, único por conta), data, valor com sinal e histórico; conciliada com um lançamento pago ou uma transferência da conta, ou ignorada. nr_line é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_bank_import e fin_bank_reconcile (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_line",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da linha na filial."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": false,
          "description": "Conta do extrato."
        },
        {
          "name": "vc_fitid",
          "type": "varchar(100)",
          "nullable": false,
          "description": "Id da transação no banco (FITID do OFX); reimportar não duplica."
        },
        {
          "name": "dt_posted",
          "type": "date",
          "nullable": false,
          "description": "Data do lançamento no banco."
        },
        {
          "name": "vl_amount",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor com sinal (entrada +, saída −)."
        },
        {
          "name": "vc_memo",
          "type": "varchar(255)",
          "nullable": true,
          "description": "Histórico do banco."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Pendente",
            "2": "Conciliada",
            "90": "Ignorada"
          }
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": true,
          "description": "Lançamento conciliado."
        },
        {
          "name": "nr_transfer",
          "type": "bigint",
          "fk": "fin_transfer.nr_transfer",
          "nullable": true,
          "description": "Transferência conciliada."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem importou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_recurrence",
      "title": "Conta recorrente",
      "description": "Regra de conta que se repete todo mês no mesmo dia (aluguel, salário, internet...), sem data final ou até uma data. Os lançamentos são gerados a partir dela (od.fn_fin_recurrence_fill) até 12 meses à frente; alterar a regra muda os futuros em aberto e encerrar cancela os futuros. nr_recurrence é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_recurrence_save (permissão na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_recurrence",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial da regra na filial."
        },
        {
          "name": "it_kind",
          "type": "smallint",
          "nullable": false,
          "description": "Tipo.",
          "values": {
            "1": "A receber",
            "2": "A pagar"
          }
        },
        {
          "name": "nr_category",
          "type": "bigint",
          "fk": "fin_category.nr_category",
          "nullable": false,
          "description": "Categoria (do mesmo tipo)."
        },
        {
          "name": "nr_account",
          "type": "bigint",
          "fk": "fin_account.nr_account",
          "nullable": true,
          "description": "Conta prevista."
        },
        {
          "name": "nr_supplier",
          "type": "bigint",
          "fk": "fin_supplier.nr_supplier",
          "nullable": true,
          "description": "Fornecedor."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "fk": "patient.nr_patient",
          "nullable": true,
          "description": "Paciente (receita recorrente, ex.: mensalidade)."
        },
        {
          "name": "vc_description",
          "type": "varchar(140)",
          "nullable": false,
          "description": "Descrição dos lançamentos."
        },
        {
          "name": "vl_amount",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor de cada mês (> 0)."
        },
        {
          "name": "it_day",
          "type": "smallint",
          "nullable": false,
          "description": "Dia do vencimento (1 a 31; em meses curtos vira o último dia)."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": true,
          "description": "Forma de pagamento prevista.",
          "values": {
            "1": "Dinheiro",
            "2": "Pix",
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "5": "Transferência",
            "6": "Boleto",
            "7": "Cheque",
            "9": "Outro"
          }
        },
        {
          "name": "dt_start",
          "type": "date",
          "nullable": false,
          "description": "A partir de quando gera (primeiro vencimento possível)."
        },
        {
          "name": "dt_end",
          "type": "date",
          "nullable": true,
          "description": "Até quando gera (nulo = sem data final)."
        },
        {
          "name": "dt_generated",
          "type": "date",
          "nullable": true,
          "description": "Último vencimento já gerado (controle da geração)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativa",
            "90": "Encerrada"
          }
        },
        {
          "name": "vc_notes",
          "type": "varchar(500)",
          "nullable": true,
          "description": "Observações (vão para os lançamentos)."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem cadastrou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_attachment",
      "title": "Anexo de conta",
      "description": "Arquivo anexado a uma conta a pagar/receber: documento (nota, boleto) ou comprovante de pagamento. O arquivo fica no Storage (bucket privado finance, caminho empresa/filial/conta/uuid.ext); upload e download só por URL assinada da Edge Function fin-attachment. Excluir é lógico. nr_attachment é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_attachment_save (permissão de alterar na tela FINANCE).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_attachment",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do anexo na filial."
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": false,
          "description": "Conta do anexo."
        },
        {
          "name": "it_type",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Tipo.",
          "values": {
            "1": "Documento (nota, boleto)",
            "2": "Comprovante de pagamento"
          }
        },
        {
          "name": "vc_path",
          "type": "varchar(300)",
          "nullable": false,
          "description": "Caminho no bucket finance (único)."
        },
        {
          "name": "vc_name",
          "type": "varchar(200)",
          "nullable": false,
          "description": "Nome original do arquivo."
        },
        {
          "name": "vc_mime",
          "type": "varchar(100)",
          "nullable": true,
          "description": "Tipo do arquivo (PDF ou imagem)."
        },
        {
          "name": "qt_bytes",
          "type": "bigint",
          "nullable": true,
          "description": "Tamanho em bytes (até 10 MB)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação.",
          "values": {
            "1": "Ativo",
            "90": "Excluído"
          }
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Quem anexou."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "fin_receipt",
      "title": "Recibo",
      "description": "Recibo numerado de uma conta a receber paga: número sequencial por filial com o prefixo das configurações, pagador, valor, data e forma do pagamento. Emitir de novo devolve o recibo ativo; cancelado não libera o número.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via fin_receipt_issue (criar na tela FINANCE) e fin_receipt_cancel (alterar).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_receipt",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do recibo na filial."
        },
        {
          "name": "vc_number",
          "type": "varchar(30)",
          "nullable": false,
          "description": "Número impresso (prefixo + número com 6 dígitos); único na filial."
        },
        {
          "name": "nr_entry",
          "type": "bigint",
          "fk": "fin_entry.nr_entry",
          "nullable": false,
          "description": "Conta a receber paga do recibo (um recibo ativo por conta)."
        },
        {
          "name": "vl_amount",
          "type": "numeric(14,2)",
          "nullable": false,
          "description": "Valor recebido (o pago da conta)."
        },
        {
          "name": "dt_paid",
          "type": "date",
          "nullable": false,
          "description": "Data do pagamento."
        },
        {
          "name": "it_payment_method",
          "type": "smallint",
          "nullable": true,
          "description": "Forma de pagamento.",
          "values": {
            "1": "Dinheiro",
            "2": "Pix",
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "5": "Transferência",
            "6": "Boleto",
            "7": "Cheque",
            "9": "Outro"
          }
        },
        {
          "name": "vc_payer_name",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Nome de quem pagou (padrão: o paciente da conta)."
        },
        {
          "name": "vc_payer_document",
          "type": "varchar(14)",
          "nullable": true,
          "description": "CPF ou CNPJ do pagador, só dígitos."
        },
        {
          "name": "vc_description",
          "type": "varchar(200)",
          "nullable": false,
          "description": "Referente a (padrão: a descrição da conta)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do recibo (cancelado não libera o número).",
          "values": {
            "1": "Emitido",
            "90": "Cancelado"
          }
        },
        {
          "name": "vc_cancel_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do cancelamento."
        },
        {
          "name": "nr_user_created",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": true,
          "description": "Usuário que emitiu."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "branch_setting",
      "title": "Configurações da filial",
      "description": "Preferências da filial (uma linha; sem linha valem os padrões): agenda (intervalo de visualização, consultas do mesmo profissional no mesmo horário, agendar fora do horário de atendimento), cadastro de pacientes (número de prontuário automático, CPF e celular obrigatórios) e financeiro (bloqueio de pacientes com conta vencida, caixa do dia, formas de pagamento aceitas, multa e juros por atraso).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via settings_save (permissão de alterar na tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "qt_slot_minutes",
          "type": "smallint",
          "nullable": false,
          "default": "15",
          "description": "Intervalo de visualização da agenda (5, 15, 20 ou 30 minutos)."
        },
        {
          "name": "qt_max_parallel",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Quantas consultas do mesmo profissional podem ocupar o mesmo horário (1 a 20; encaixe não conta)."
        },
        {
          "name": "id_allow_outside_hours",
          "type": "boolean",
          "nullable": false,
          "default": "true",
          "description": "Permite agendar fora do horário de atendimento do profissional."
        },
        {
          "name": "id_auto_record_number",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Numera o prontuário automaticamente no cadastro do paciente."
        },
        {
          "name": "nr_next_record",
          "type": "bigint",
          "nullable": false,
          "default": "1",
          "description": "Próximo número de prontuário."
        },
        {
          "name": "vc_patient_required",
          "type": "text[]",
          "nullable": false,
          "default": "'{}'",
          "description": "Campos obrigatórios no cadastro do paciente além de nome, nascimento e CPF (sempre obrigatórios): rg, gender (gênero), marital_status, education, source (como conheceu), referral (indicado por), mobile, phone, email (ou não possui e-mail), address (CEP, endereço, número, bairro, cidade e UF), profession, plan (convênio)."
        },
        {
          "name": "it_debt_rule",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "O que a agenda faz ao marcar consulta de paciente com conta a receber vencida (além da tolerância).",
          "values": {
            "1": "Não bloquear",
            "2": "Avisar",
            "3": "Só o administrador da empresa libera",
            "4": "Bloquear"
          }
        },
        {
          "name": "qt_debt_days",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Dias de tolerância depois do vencimento antes de valer o bloqueio de inadimplentes (0 a 365)."
        },
        {
          "name": "id_cash_enabled",
          "type": "boolean",
          "nullable": false,
          "default": "true",
          "description": "Usa o caixa do dia (abrir e fechar caixa). Desligado, não abre caixa novo."
        },
        {
          "name": "it_payment_methods",
          "type": "smallint[]",
          "nullable": false,
          "default": "'{1,2,3,4,5,6,7,9}'",
          "description": "Formas de pagamento aceitas ao receber (baixa de conta a receber e fechamento da consulta); ao menos uma.",
          "values": {
            "1": "Dinheiro",
            "2": "Pix",
            "3": "Cartão de crédito",
            "4": "Cartão de débito",
            "5": "Transferência",
            "6": "Boleto",
            "7": "Cheque",
            "9": "Outro"
          }
        },
        {
          "name": "pc_late_fee",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Multa por atraso nas contas a receber (% do valor, 0 a 10)."
        },
        {
          "name": "pc_late_interest",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "Juros de mora ao mês nas contas a receber (%, pro rata por dia, 0 a 10)."
        },
        {
          "name": "vc_receipt_prefix",
          "type": "varchar(10)",
          "nullable": false,
          "default": "''",
          "description": "Prefixo do número impresso dos recibos (ex. REC-; letras, números, - / .)."
        },
        {
          "name": "nr_next_receipt",
          "type": "bigint",
          "nullable": false,
          "default": "1",
          "description": "Próximo número de recibo da filial (números já usados são pulados)."
        },
        {
          "name": "pc_budget_max_discount",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "10",
          "description": "Desconto máximo do orçamento sem aprovação (%, 0 a 100); acima disso só o administrador da empresa aprova."
        },
        {
          "name": "qt_budget_valid_days",
          "type": "smallint",
          "nullable": false,
          "default": "30",
          "description": "Validade padrão do orçamento em dias (1 a 365)."
        },
        {
          "name": "id_budget_request_approval",
          "type": "boolean",
          "nullable": false,
          "default": "true",
          "description": "Desconto acima do máximo pode ir para aprovação do administrador; desligado, é recusado (BUDGET_DISCOUNT_OVER_MAX)."
        },
        {
          "name": "id_budget_admin_below_min",
          "type": "boolean",
          "nullable": false,
          "default": "true",
          "description": "O administrador pode aprovar orçamento com item abaixo do preço mínimo da precificação; desligado, ninguém aprova (BUDGET_BELOW_MIN)."
        },
        {
          "name": "id_budget_reduction_as_discount",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Valor do item abaixo do valor cobrado hoje do procedimento conta como desconto no limite."
        },
        {
          "name": "it_open_rule",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "O que a agenda faz com paciente que tem conta a receber em aberto (mesmo não vencida); vale a regra mais forte entre esta e it_debt_rule.",
          "values": {
            "1": "Não bloquear",
            "2": "Avisar",
            "3": "Só o administrador da empresa libera",
            "4": "Bloquear"
          }
        },
        {
          "name": "it_late_edit",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Multa e juros na baixa: receber menos que valor + acréscimos.",
          "values": {
            "0": "Editáveis",
            "1": "Só o administrador reduz",
            "2": "Não podem ser reduzidos"
          }
        },
        {
          "name": "pc_dre_revenue_tax",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "DRE: impostos sobre a receita bruta para a estimativa (Simples, ISS, PIS/COFINS; % 0 a 50; zero não estima)."
        },
        {
          "name": "pc_dre_income_tax",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "DRE: IRPJ sobre o resultado antes dos impostos (% 0 a 50; zero não estima)."
        },
        {
          "name": "pc_dre_csll",
          "type": "numeric(5,2)",
          "nullable": false,
          "default": "0",
          "description": "DRE: CSLL sobre o resultado antes dos impostos (% 0 a 50; zero não estima)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "branch_hour",
      "title": "Horário de funcionamento",
      "description": "Horário de funcionamento da clínica por dia da semana (um ou mais intervalos por dia, sem sobreposição). nr_hour é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via settings_save (permissão de alterar na tela SETTINGS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_hour",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do intervalo na filial."
        },
        {
          "name": "it_weekday",
          "type": "smallint",
          "nullable": false,
          "description": "Dia da semana.",
          "values": {
            "0": "Domingo",
            "1": "Segunda",
            "2": "Terça",
            "3": "Quarta",
            "4": "Quinta",
            "5": "Sexta",
            "6": "Sábado"
          }
        },
        {
          "name": "qt_minute_start",
          "type": "smallint",
          "nullable": false,
          "description": "Início (minutos desde 0h)."
        },
        {
          "name": "qt_minute_end",
          "type": "smallint",
          "nullable": false,
          "description": "Fim (minutos desde 0h; depois do início)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient",
      "title": "Paciente",
      "description": "Ficha do paciente da filial: dados cadastrais (nome, apelido, CPF, RG, nascimento, gênero, estado civil, escolaridade, como conheceu, indicado por), contato e endereço, dados complementares (prontuário, profissão, plano/convênio, filiação, representante legal) e alerta de retorno. Documentos, telefones e CEP só com dígitos. nr_patient é sequencial por filial.",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_save (permissão na tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "nullable": false,
          "description": "Número sequencial do paciente na filial."
        },
        {
          "name": "vc_name",
          "type": "varchar(120)",
          "nullable": false,
          "description": "Nome completo."
        },
        {
          "name": "vc_nickname",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Apelido / como prefere ser chamado."
        },
        {
          "name": "vc_cpf",
          "type": "varchar(11)",
          "uk": "patient_vc_cpf_uk",
          "nullable": true,
          "description": "CPF só com dígitos, validado (ad.fn_cpf_is_valid) e único na filial (patient_vc_cpf_uk)."
        },
        {
          "name": "vc_rg",
          "type": "varchar(20)",
          "nullable": true,
          "description": "RG, como digitado."
        },
        {
          "name": "dt_birth",
          "type": "date",
          "nullable": false,
          "description": "Data de nascimento (obrigatória; a idade é calculada nas RPCs)."
        },
        {
          "name": "it_gender",
          "type": "smallint",
          "nullable": true,
          "description": "Gênero.",
          "values": {
            "1": "Masculino",
            "2": "Feminino",
            "3": "Outro"
          }
        },
        {
          "name": "it_marital_status",
          "type": "smallint",
          "nullable": true,
          "description": "Estado civil.",
          "values": {
            "1": "Solteiro(a)",
            "2": "Casado(a)",
            "3": "Divorciado(a)",
            "4": "Viúvo(a)",
            "5": "União estável"
          }
        },
        {
          "name": "it_education",
          "type": "smallint",
          "nullable": true,
          "description": "Escolaridade.",
          "values": {
            "1": "Ensino fundamental",
            "2": "Ensino médio",
            "3": "Ensino superior",
            "4": "Pós-graduação"
          }
        },
        {
          "name": "it_source",
          "type": "smallint",
          "nullable": true,
          "description": "Como conheceu a clínica.",
          "values": {
            "1": "Google",
            "2": "Instagram",
            "3": "Facebook",
            "4": "Indicação",
            "5": "Escola",
            "6": "Outdoor",
            "7": "Panfleto",
            "8": "Placa",
            "9": "Plano / convênio",
            "10": "Rádio",
            "11": "TV",
            "12": "Revista",
            "99": "Outros"
          }
        },
        {
          "name": "vc_referral",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Indicado por (nome de quem indicou)."
        },
        {
          "name": "vc_notes",
          "type": "text",
          "nullable": true,
          "description": "Observações do cadastro."
        },
        {
          "name": "vc_phone",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Telefone fixo, só dígitos (DDD + número)."
        },
        {
          "name": "vc_mobile",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Celular / WhatsApp, só dígitos (DDD + número)."
        },
        {
          "name": "vc_phone_other",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Outro telefone, só dígitos."
        },
        {
          "name": "vc_contact_name",
          "type": "varchar(80)",
          "nullable": true,
          "description": "De quem é o celular de contato (quando não é do paciente)."
        },
        {
          "name": "vc_email",
          "type": "varchar(120)",
          "nullable": true,
          "description": "E-mail em minúsculas, validado (ad.fn_email_is_valid)."
        },
        {
          "name": "id_no_email",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Paciente não possui e-mail (limpa vc_email)."
        },
        {
          "name": "vc_zip",
          "type": "varchar(8)",
          "nullable": true,
          "description": "CEP, só dígitos."
        },
        {
          "name": "vc_state",
          "type": "varchar(2)",
          "nullable": true,
          "description": "UF, maiúscula."
        },
        {
          "name": "vc_city",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Cidade."
        },
        {
          "name": "vc_address",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Endereço (logradouro)."
        },
        {
          "name": "vc_address_number",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Número."
        },
        {
          "name": "vc_district",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Bairro."
        },
        {
          "name": "vc_address_complement",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Complemento."
        },
        {
          "name": "vc_record_number",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Número do prontuário (numeração própria da clínica)."
        },
        {
          "name": "vc_profession",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Profissão."
        },
        {
          "name": "vc_workplace",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Local de trabalho."
        },
        {
          "name": "vc_work_time",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Tempo de trabalho."
        },
        {
          "name": "vc_plan_name",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Nome do plano / convênio."
        },
        {
          "name": "vc_plan_number",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Número da carteirinha do plano."
        },
        {
          "name": "vc_father_name",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Filiação: nome do pai."
        },
        {
          "name": "vc_father_cpf",
          "type": "varchar(11)",
          "nullable": true,
          "description": "CPF do pai, só dígitos, validado."
        },
        {
          "name": "vc_father_rg",
          "type": "varchar(20)",
          "nullable": true,
          "description": "RG do pai."
        },
        {
          "name": "vc_father_profession",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Profissão do pai."
        },
        {
          "name": "vc_mother_name",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Filiação: nome da mãe."
        },
        {
          "name": "vc_mother_cpf",
          "type": "varchar(11)",
          "nullable": true,
          "description": "CPF da mãe, só dígitos, validado."
        },
        {
          "name": "vc_mother_rg",
          "type": "varchar(20)",
          "nullable": true,
          "description": "RG da mãe."
        },
        {
          "name": "vc_mother_profession",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Profissão da mãe."
        },
        {
          "name": "vc_guardian_name",
          "type": "varchar(120)",
          "nullable": true,
          "description": "Representante legal: nome."
        },
        {
          "name": "vc_guardian_cpf",
          "type": "varchar(11)",
          "nullable": true,
          "description": "CPF do representante legal, só dígitos, validado."
        },
        {
          "name": "vc_guardian_rg",
          "type": "varchar(20)",
          "nullable": true,
          "description": "RG do representante legal."
        },
        {
          "name": "vc_guardian_phone",
          "type": "varchar(11)",
          "nullable": true,
          "description": "Telefone do representante legal, só dígitos."
        },
        {
          "name": "dt_return_alert",
          "type": "date",
          "nullable": true,
          "description": "Alerta de retorno: quando lembrar de chamar o paciente."
        },
        {
          "name": "vc_return_alert",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Alerta de retorno: motivo / observação."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do paciente.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "schema": "od",
      "name": "patient_note",
      "title": "Nota do paciente",
      "description": "Notas gerais da ficha do paciente (card Notas gerais): texto livre com autor e data. Exclusão lógica (it_status 90).",
      "rls": "SELECT: filiais acessíveis (private.fn_my_branches). Escrita só via patient_note_save (permissão na tela PATIENTS).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "patient.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "patient.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_patient",
          "type": "bigint",
          "pk": 3,
          "fk": "patient.nr_patient",
          "nullable": false,
          "description": "Número do paciente."
        },
        {
          "name": "nr_note",
          "type": "bigint",
          "pk": 4,
          "nullable": false,
          "description": "Número sequencial da nota no paciente."
        },
        {
          "name": "vc_note",
          "type": "text",
          "nullable": false,
          "description": "Texto da nota."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Autor da nota (usuário da sessão)."
        },
        {
          "name": "dh_note",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da nota."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da nota (exclusão é lógica).",
          "values": {
            "1": "Ativa",
            "90": "Excluída"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    }
  ],
  "external_entities": [
    {
      "name": "auth_users",
      "title": "auth.users (Supabase Auth)",
      "description": "Usuários autenticados pelo Supabase (e-mail, senha, OTP, social, 2FA). Gerenciado pela Supabase; referenciado por ad.app_user.uu_auth."
    }
  ],
  "relations": [
    {
      "from": "screen",
      "to": "access_profile_screen",
      "card": "||--o{",
      "label": "liberada para perfis"
    },
    {
      "from": "access_profile",
      "to": "access_profile_screen",
      "card": "||--o{",
      "label": "telas do perfil"
    },
    {
      "from": "app_user",
      "to": "event_log",
      "card": "||--o{",
      "label": "atividades"
    },
    {
      "from": "screen",
      "to": "event_log",
      "card": "||--o{",
      "label": "eventos na tela"
    },
    {
      "from": "company",
      "to": "branch",
      "card": "||--o{",
      "label": "possui filiais"
    },
    {
      "from": "company",
      "to": "access_profile",
      "card": "||--o{",
      "label": "define perfis"
    },
    {
      "from": "company",
      "to": "company_user",
      "card": "||--o{",
      "label": "tem usuários"
    },
    {
      "from": "app_user",
      "to": "company_user",
      "card": "||--o{",
      "label": "participa de empresas"
    },
    {
      "from": "auth_users",
      "to": "app_user",
      "card": "||--||",
      "label": "uu_auth"
    },
    {
      "from": "branch",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "acesso por filial"
    },
    {
      "from": "company_user",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "perfis nas filiais"
    },
    {
      "from": "access_profile",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "perfil atribuído"
    },
    {
      "from": "app_user",
      "to": "access_log",
      "card": "||--o{",
      "label": "acessos"
    },
    {
      "from": "branch",
      "to": "pricing_param",
      "card": "||--o|",
      "label": "parâmetros de preço"
    },
    {
      "from": "branch",
      "to": "clinic_expense",
      "card": "||--o{",
      "label": "despesas"
    },
    {
      "from": "branch",
      "to": "pricing_fee",
      "card": "||--o{",
      "label": "taxas adicionais"
    },
    {
      "from": "branch",
      "to": "material",
      "card": "||--o{",
      "label": "materiais"
    },
    {
      "from": "branch",
      "to": "specialty",
      "card": "||--o{",
      "label": "especialidades"
    },
    {
      "from": "specialty",
      "to": "procedure",
      "card": "|o--o{",
      "label": "agrupa procedimentos"
    },
    {
      "from": "branch",
      "to": "procedure",
      "card": "||--o{",
      "label": "procedimentos"
    },
    {
      "from": "procedure",
      "to": "procedure_material",
      "card": "||--o{",
      "label": "usa materiais"
    },
    {
      "from": "material",
      "to": "procedure_material",
      "card": "||--o{",
      "label": "usado em"
    },
    {
      "from": "branch",
      "to": "patient",
      "card": "||--o{",
      "label": "pacientes"
    },
    {
      "from": "branch",
      "to": "professional",
      "card": "||--o{",
      "label": "profissionais"
    },
    {
      "from": "professional",
      "to": "professional_schedule",
      "card": "||--o{",
      "label": "horário de atendimento"
    },
    {
      "from": "app_user",
      "to": "professional",
      "card": "|o--o{",
      "label": "é o profissional"
    },
    {
      "from": "branch",
      "to": "fin_account",
      "card": "||--o{",
      "label": "contas"
    },
    {
      "from": "branch",
      "to": "fin_category",
      "card": "||--o{",
      "label": "plano de contas"
    },
    {
      "from": "branch",
      "to": "fin_supplier",
      "card": "||--o{",
      "label": "fornecedores"
    },
    {
      "from": "fin_category",
      "to": "fin_entry",
      "card": "||--o{",
      "label": "classifica"
    },
    {
      "from": "fin_account",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "movimenta"
    },
    {
      "from": "fin_supplier",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "cobra"
    },
    {
      "from": "fin_account",
      "to": "fin_cash_session",
      "card": "||--o{",
      "label": "caixa do dia"
    },
    {
      "from": "fin_cash_session",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "recebe no caixa"
    },
    {
      "from": "fin_account",
      "to": "fin_card_rate",
      "card": "||--o{",
      "label": "recebe da taxa"
    },
    {
      "from": "fin_entry",
      "to": "fin_receivable",
      "card": "||--o{",
      "label": "gera recebíveis"
    },
    {
      "from": "fin_card_rate",
      "to": "fin_receivable",
      "card": "|o--o{",
      "label": "aplica"
    },
    {
      "from": "fin_transfer",
      "to": "fin_receivable",
      "card": "|o--o|",
      "label": "confirma"
    },
    {
      "from": "branch",
      "to": "health_plan",
      "card": "||--o{",
      "label": "convênios"
    },
    {
      "from": "health_plan",
      "to": "health_plan_price",
      "card": "||--o{",
      "label": "tabela de preço"
    },
    {
      "from": "procedure",
      "to": "health_plan_price",
      "card": "||--o{",
      "label": "preço no convênio"
    },
    {
      "from": "health_plan",
      "to": "health_guide",
      "card": "||--o{",
      "label": "guias"
    },
    {
      "from": "patient",
      "to": "health_guide",
      "card": "||--o{",
      "label": "atendido por convênio"
    },
    {
      "from": "health_guide",
      "to": "health_guide_item",
      "card": "||--|{",
      "label": "procedimentos"
    },
    {
      "from": "fin_entry",
      "to": "health_guide",
      "card": "|o--o{",
      "label": "faturamento"
    },
    {
      "from": "fin_account",
      "to": "fin_bank_line",
      "card": "||--o{",
      "label": "extrato do banco"
    },
    {
      "from": "fin_entry",
      "to": "fin_bank_line",
      "card": "|o--o|",
      "label": "concilia"
    },
    {
      "from": "fin_category",
      "to": "fin_recurrence",
      "card": "||--o{",
      "label": "classifica"
    },
    {
      "from": "fin_recurrence",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "gera"
    },
    {
      "from": "fin_entry",
      "to": "fin_attachment",
      "card": "||--o{",
      "label": "anexa"
    },
    {
      "from": "patient",
      "to": "budget",
      "card": "||--o{",
      "label": "orçamentos"
    },
    {
      "from": "budget",
      "to": "budget_item",
      "card": "||--|{",
      "label": "itens"
    },
    {
      "from": "anamnesis_model",
      "to": "anamnesis_question",
      "card": "||--|{",
      "label": "perguntas"
    },
    {
      "from": "patient",
      "to": "patient_anamnesis",
      "card": "||--o{",
      "label": "anamneses"
    },
    {
      "from": "anamnesis_model",
      "to": "patient_anamnesis",
      "card": "||--o{",
      "label": "preenchida"
    },
    {
      "from": "patient_anamnesis",
      "to": "patient_anamnesis_answer",
      "card": "||--|{",
      "label": "respostas"
    },
    {
      "from": "patient",
      "to": "clinical_evolution",
      "card": "||--o{",
      "label": "evoluções"
    },
    {
      "from": "budget_item",
      "to": "clinical_evolution",
      "card": "||--o|",
      "label": "realizado"
    },
    {
      "from": "professional",
      "to": "clinical_evolution",
      "card": "||--o{",
      "label": "atendeu"
    },
    {
      "from": "patient",
      "to": "tooth_mark",
      "card": "||--o{",
      "label": "odontograma"
    },
    {
      "from": "patient",
      "to": "patient_document",
      "card": "||--o{",
      "label": "documentos"
    },
    {
      "from": "document_template",
      "to": "patient_document",
      "card": "||--o{",
      "label": "emitido"
    },
    {
      "from": "patient_document",
      "to": "patient_document_item",
      "card": "||--o{",
      "label": "medicamentos"
    },
    {
      "from": "medication",
      "to": "patient_document_item",
      "card": "||--o{",
      "label": "receitado"
    },
    {
      "from": "procedure",
      "to": "budget_item",
      "card": "||--o{",
      "label": "orçado"
    },
    {
      "from": "budget",
      "to": "fin_entry",
      "card": "||--o{",
      "label": "gera contas"
    },
    {
      "from": "fin_entry",
      "to": "fin_receipt",
      "card": "||--o{",
      "label": "recibos"
    },
    {
      "from": "fin_account",
      "to": "fin_transfer",
      "card": "||--o{",
      "label": "transfere"
    },
    {
      "from": "fin_cash_session",
      "to": "fin_transfer",
      "card": "|o--o{",
      "label": "sangria / suprimento"
    },
    {
      "from": "appointment",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "fecha o atendimento"
    },
    {
      "from": "professional",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "comissão"
    },
    {
      "from": "patient",
      "to": "fin_entry",
      "card": "|o--o{",
      "label": "paga"
    },
    {
      "from": "branch",
      "to": "appointment",
      "card": "||--o{",
      "label": "agenda"
    },
    {
      "from": "patient",
      "to": "appointment",
      "card": "|o--o{",
      "label": "consultas"
    },
    {
      "from": "professional",
      "to": "appointment",
      "card": "|o--o{",
      "label": "atende"
    },
    {
      "from": "procedure",
      "to": "appointment",
      "card": "|o--o{",
      "label": "previsto em"
    },
    {
      "from": "patient",
      "to": "patient_note",
      "card": "||--o{",
      "label": "notas"
    },
    {
      "from": "app_user",
      "to": "patient_note",
      "card": "||--o{",
      "label": "autor"
    }
  ],
  "functions": [
    {
      "name": "session_context",
      "signature": "ad.session_context(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Login do app após o Supabase Auth: devolve usuário, empresas → filiais → perfis acessíveis (com it_level e id_admin) e vínculos bloqueados com motivo; grava access_log e dh_last_login. Cada filial traz permissions: telas que o usuário pode ler/criar/alterar (nível 100 tem todas; DASHBOARD sempre). Empresa que exige 2FA de quem está sem o segundo fator confirmado vem em blocked com SESSION_MFA_REQUIRED; mfa.vc_aal informa o nível da sessão.",
      "errors": [
        "VERSION_MISMATCH",
        "SESSION_USER_NOT_FOUND",
        "SESSION_USER_INACTIVE",
        "SESSION_USER_BLOCKED",
        "SESSION_COMPANY_BLOCKED",
        "SESSION_COMPANY_INACTIVE",
        "SESSION_USER_COMPANY_BLOCKED",
        "SESSION_USER_COMPANY_INACTIVE",
        "SESSION_WITHOUT_PROFILE"
      ]
    },
    {
      "name": "company_create",
      "signature": "ad.company_create(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Onboarding: cria empresa, matriz (filial 1), perfis Administrador/Usuário e vincula o criador como administrador. Qualquer usuário ativo pode criar.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_CREATE_USER_NOT_FOUND",
        "COMPANY_CREATE_USER_INACTIVE",
        "COMPANY_CREATE_NAME_REQUIRED",
        "COMPANY_CREATE_CNPJ_INVALID",
        "COMPANY_CREATE_CNPJ_IN_USE",
        "COMPANY_CREATE_EMAIL_INVALID",
        "COMPANY_CREATE_TIMEZONE_INVALID"
      ]
    },
    {
      "name": "company_update",
      "signature": "ad.company_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Atualização parcial dos dados cadastrais da empresa. Somente administrador. Situação/bloqueio só por service_role. Aceita it_mfa_policy (2FA obrigatória: 0 não, 1 administradores, 2 todos); para ligar, quem altera precisa estar com 2FA na sessão (JWT aal2).",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_UPDATE_COMPANY_REQUIRED",
        "COMPANY_UPDATE_FORBIDDEN",
        "COMPANY_UPDATE_NAME_REQUIRED",
        "COMPANY_UPDATE_CNPJ_INVALID",
        "COMPANY_UPDATE_CNPJ_IN_USE",
        "COMPANY_UPDATE_EMAIL_INVALID",
        "COMPANY_UPDATE_MFA_INVALID",
        "COMPANY_UPDATE_MFA_FIRST"
      ]
    },
    {
      "name": "branch_create",
      "signature": "ad.branch_create(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria filial (numeração sequencial por empresa, serializada com FOR UPDATE na empresa) e vincula o criador com o seu perfil de maior nível. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_CREATE_COMPANY_REQUIRED",
        "BRANCH_CREATE_FORBIDDEN",
        "BRANCH_CREATE_NAME_REQUIRED",
        "BRANCH_CREATE_CNPJ_INVALID",
        "BRANCH_CREATE_CNPJ_IN_USE",
        "BRANCH_CREATE_EMAIL_INVALID",
        "BRANCH_CREATE_TIMEZONE_INVALID"
      ]
    },
    {
      "name": "branch_update",
      "signature": "ad.branch_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Atualização parcial da filial, inclusive transferência de matriz (id_main). Somente administrador. Também telefone adicional, responsável técnico (nome, CRO e UF) e cidade do foro.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_UPDATE_KEY_REQUIRED",
        "BRANCH_UPDATE_FORBIDDEN",
        "BRANCH_UPDATE_NOT_FOUND",
        "BRANCH_UPDATE_NAME_REQUIRED",
        "BRANCH_UPDATE_CNPJ_INVALID",
        "BRANCH_UPDATE_CNPJ_IN_USE",
        "BRANCH_UPDATE_EMAIL_INVALID",
        "BRANCH_UPDATE_TIMEZONE_INVALID",
        "BRANCH_UPDATE_PHONE_INVALID",
        "BRANCH_UPDATE_STATE_INVALID"
      ]
    },
    {
      "name": "access_profile_save",
      "signature": "ad.access_profile_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou atualiza (U) perfis de acesso da empresa; screens (opcional) substitui as permissões por tela (ler/criar/alterar). Guarda contra deixar a empresa sem administrador ativo. Grava event_log. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "ACCESS_PROFILE_ACTION_INVALID",
        "ACCESS_PROFILE_COMPANY_REQUIRED",
        "ACCESS_PROFILE_FORBIDDEN",
        "ACCESS_PROFILE_NAME_REQUIRED",
        "ACCESS_PROFILE_NAME_IN_USE",
        "ACCESS_PROFILE_LEVEL_INVALID",
        "ACCESS_PROFILE_REQUIRED",
        "ACCESS_PROFILE_NOT_FOUND",
        "ACCESS_PROFILE_STATUS_INVALID",
        "ACCESS_PROFILE_LAST_ADMIN",
        "ACCESS_PROFILE_SCREENS_INVALID",
        "ACCESS_PROFILE_SCREEN_INVALID"
      ]
    },
    {
      "name": "company_user_save",
      "signature": "ad.company_user_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Vincula (I, por e-mail de usuário já cadastrado no Auth), altera (U: situação, motivo, filiais/perfis) ou remove (D) um usuário da empresa. Guarda do último administrador. Somente administrador. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_USER_ACTION_INVALID",
        "COMPANY_USER_COMPANY_REQUIRED",
        "COMPANY_USER_FORBIDDEN",
        "COMPANY_USER_EMAIL_REQUIRED",
        "COMPANY_USER_EMAIL_NOT_FOUND",
        "COMPANY_USER_ALREADY_LINKED",
        "COMPANY_USER_USER_REQUIRED",
        "COMPANY_USER_NOT_FOUND",
        "COMPANY_USER_STATUS_INVALID",
        "COMPANY_USER_BRANCHES_REQUIRED",
        "COMPANY_USER_BRANCH_INVALID",
        "COMPANY_USER_PROFILE_INVALID",
        "COMPANY_USER_LAST_ADMIN"
      ]
    },
    {
      "name": "user_update",
      "signature": "ad.user_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Autoatendimento: nome, CPF (validado), telefones e avatar do próprio usuário. E-mail/senha mudam pelo Supabase Auth.",
      "errors": [
        "VERSION_MISMATCH",
        "USER_UPDATE_USER_NOT_FOUND",
        "USER_UPDATE_NAME_REQUIRED",
        "USER_UPDATE_CPF_INVALID",
        "USER_UPDATE_CPF_IN_USE"
      ]
    },
    {
      "name": "branch_list",
      "signature": "ad.branch_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Lista as filiais da empresa: administrador vê todas, usuário comum só as filiais em que tem perfil ativo. Opção id_include_inactive. O app nunca lê ad.branch direto.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_LIST_COMPANY_REQUIRED",
        "BRANCH_LIST_FORBIDDEN"
      ]
    },
    {
      "name": "access_profile_list",
      "signature": "ad.access_profile_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Lista os perfis de acesso da empresa com a quantidade de usuários e as telas liberadas (ler/criar/alterar) de cada um. Qualquer usuário ativo da empresa. Opção id_include_inactive.",
      "errors": [
        "VERSION_MISMATCH",
        "ACCESS_PROFILE_LIST_COMPANY_REQUIRED",
        "ACCESS_PROFILE_LIST_FORBIDDEN"
      ]
    },
    {
      "name": "company_user_list",
      "signature": "ad.company_user_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Lista paginada dos usuários da empresa com cadastro, situação e filiais × perfis; filtros por nome/e-mail, situação e filial. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_USER_LIST_COMPANY_REQUIRED",
        "COMPANY_USER_LIST_FORBIDDEN",
        "COMPANY_USER_LIST_STATUS_INVALID"
      ]
    },
    {
      "name": "access_log_list",
      "signature": "ad.access_log_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Log de acesso paginado no contexto da empresa (padrão: últimos 30 dias). Administrador vê os acessos à empresa e os sem empresa escolhida dos seus usuários; usuário comum só os próprios. Filtros por usuário, app e período.",
      "errors": [
        "VERSION_MISMATCH",
        "ACCESS_LOG_LIST_COMPANY_REQUIRED",
        "ACCESS_LOG_LIST_FORBIDDEN",
        "ACCESS_LOG_LIST_APP_INVALID",
        "ACCESS_LOG_LIST_PERIOD_INVALID"
      ]
    },
    {
      "name": "screen_list",
      "signature": "ad.screen_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Catálogo de telas ativas do app na ordem do menu (uuid, código, nome, grupo). Qualquer usuário logado.",
      "errors": [
        "VERSION_MISMATCH",
        "SCREEN_LIST_FORBIDDEN"
      ]
    },
    {
      "name": "event_log_list",
      "signature": "ad.event_log_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Log de atividades paginado no contexto da empresa (padrão: últimos 30 dias), pesquisável por tela, ação, usuário, texto e período. Administrador vê a empresa; usuário comum só os próprios eventos.",
      "errors": [
        "VERSION_MISMATCH",
        "EVENT_LOG_LIST_COMPANY_REQUIRED",
        "EVENT_LOG_LIST_FORBIDDEN",
        "EVENT_LOG_LIST_ACTION_INVALID",
        "EVENT_LOG_LIST_PERIOD_INVALID"
      ]
    },
    {
      "name": "user_create_check",
      "signature": "ad.user_create_check(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Pré-checagem do cadastro de usuário pela empresa, usada pela Edge Function user-create antes de criar a conta no Auth: administrador?, e-mail válido?, já vinculado?, conta já existe?",
      "errors": [
        "VERSION_MISMATCH",
        "USER_CREATE_COMPANY_REQUIRED",
        "USER_CREATE_FORBIDDEN",
        "USER_CREATE_EMAIL_REQUIRED",
        "USER_CREATE_EMAIL_INVALID",
        "COMPANY_USER_ALREADY_LINKED"
      ]
    },
    {
      "name": "fn_event_log",
      "signature": "ad.fn_event_log(p_nr_user bigint, p_nr_company bigint, p_nr_branch bigint, p_vc_screen text, p_vc_action text, p_vc_entity text, p_vc_key text, p_vc_summary text, p_js_detail jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Grava uma linha em event_log (quem, empresa, filial, tela por código, ação, entidade, chave, resumo, detalhe). Chamada pelas RPCs que alteram dados."
    },
    {
      "name": "fn_current_user_nr",
      "signature": "private.fn_current_user_nr()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "auth.uid() → ad.app_user.nr_user do usuário logado e ativo; NULL sem sessão ou bloqueado. STABLE, SECURITY DEFINER."
    },
    {
      "name": "fn_my_branches",
      "signature": "private.fn_my_branches()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "Pares (nr_company, nr_branch) acessíveis agora: vínculo com perfil ativo, usuário ativo na empresa, empresa e filial ativas e não bloqueadas. Sem o segundo fator confirmado (JWT aal2), deixa de fora as empresas que exigem 2FA do usuário (ad.company.it_mfa_policy)."
    },
    {
      "name": "fn_my_companies",
      "signature": "private.fn_my_companies()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "Empresas com pelo menos uma filial acessível (derivada de fn_my_branches)."
    },
    {
      "name": "fn_is_company_admin",
      "signature": "private.fn_is_company_admin(p_nr_company bigint)",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "TRUE se o usuário logado tem perfil ativo de nível ≥ 100 em alguma filial acessível da empresa."
    },
    {
      "name": "fn_is_admin_of_user",
      "signature": "private.fn_is_admin_of_user(p_nr_user bigint)",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "TRUE se o usuário logado administra alguma empresa em que p_nr_user está vinculado (policy de app_user)."
    },
    {
      "name": "fn_company_has_admin",
      "signature": "ad.fn_company_has_admin(p_nr_company bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "TRUE se a empresa ainda tem um administrador ativo em filial ativa. Guarda anti-lockout de access_profile_save e company_user_save."
    },
    {
      "name": "fn_set_user_branches",
      "signature": "ad.fn_set_user_branches(p_nr_company bigint, p_nr_user bigint, p_branches jsonb, p_nr_operator bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Substitui os vínculos filial x perfil de um usuário na empresa, validando filial e perfil."
    },
    {
      "name": "fn_check_version",
      "signature": "ad.fn_check_version(p_nr_version integer, p_nr_expected integer, p_vc_function text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Compara nr_version do app com a versão do contrato da function; RAISE VERSION_MISMATCH se diferente."
    },
    {
      "name": "fn_message",
      "signature": "ad.fn_message(p_vc_key text, p_jb_params jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Monta a mensagem de erro padrão {\"Message\": chave, \"Parameters\": {...}} para o app traduzir."
    },
    {
      "name": "fn_cnpj_is_valid",
      "signature": "ad.fn_cnpj_is_valid(p_vc_cnpj text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Dígitos verificadores do CNPJ, inclusive alfanumérico (07/2026)."
    },
    {
      "name": "fn_cnpj_normalize",
      "signature": "ad.fn_cnpj_normalize(p_vc_cnpj text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Remove pontuação, maiúsculas, NULL para vazio."
    },
    {
      "name": "fn_cpf_is_valid",
      "signature": "ad.fn_cpf_is_valid(p_vc_cpf text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Dígitos verificadores do CPF."
    },
    {
      "name": "fn_email_is_valid",
      "signature": "ad.fn_email_is_valid(p_vc_email text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Validação sintática mínima de e-mail de contato."
    },
    {
      "name": "trg_audit",
      "signature": "ad.trg_audit()",
      "kind": "trigger",
      "grant": "interna",
      "description": "BEFORE INSERT OR UPDATE em todas as tabelas: preenche nr_operator, dh_created, dh_updated."
    },
    {
      "name": "trg_auth_user_sync",
      "signature": "ad.trg_auth_user_sync()",
      "kind": "trigger",
      "grant": "supabase_auth_admin",
      "description": "AFTER INSERT OR UPDATE OF email em auth.users: cria/sincroniza ad.app_user."
    },
    {
      "name": "pricing_param_get",
      "signature": "ad.pricing_param_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Aba Parâmetros da precificação: parâmetros da filial (ou padrões sugeridos quando ainda não salvos), resumo calculado (custo mensal, horas produtivas, custo da estrutura por hora, soma das taxas ativas, IR do regime), despesas, taxas adicionais e a permissão do usuário na tela PRICING. Exige leitura na tela PRICING.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN"
      ]
    },
    {
      "name": "pricing_param_save",
      "signature": "ad.pricing_param_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Salva parâmetros (parcial; vl_structure_hour_manual null volta ao cálculo), despesas e taxas adicionais (listas substituídas) da filial; valida que os percentuais do regime deixam divisor positivo. Permissão criar (1ª vez) / alterar na tela PRICING. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN",
        "PRICING_PARAM_INVALID",
        "PRICING_EXPENSES_INVALID",
        "PRICING_EXPENSE_NAME_REQUIRED",
        "PRICING_EXPENSE_TYPE_INVALID",
        "PRICING_EXPENSE_AMOUNT_INVALID",
        "PRICING_FEES_INVALID",
        "PRICING_FEE_NAME_REQUIRED",
        "PRICING_FEE_RATE_INVALID",
        "PRICING_PERCENT_TOO_HIGH"
      ]
    },
    {
      "name": "material_list",
      "signature": "ad.material_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Catálogo de materiais da filial com o custo por unidade de uso e em quantos procedimentos cada um é usado. Filtros: id_include_inactive, vc_search. Exige leitura na tela PRICING.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN"
      ]
    },
    {
      "name": "material_save",
      "signature": "ad.material_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) um material: embalagem, preço, rendimento, unidade, perda, origem do preço (manual / pesquisa de mercado), situação. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "MATERIAL_ACTION_INVALID",
        "PRICING_BRANCH_REQUIRED",
        "MATERIAL_FORBIDDEN",
        "MATERIAL_NAME_REQUIRED",
        "MATERIAL_NAME_IN_USE",
        "MATERIAL_PRICE_INVALID",
        "MATERIAL_YIELD_INVALID",
        "MATERIAL_WASTE_INVALID",
        "MATERIAL_SOURCE_INVALID",
        "MATERIAL_STATUS_INVALID",
        "MATERIAL_REQUIRED",
        "MATERIAL_NOT_FOUND"
      ]
    },
    {
      "name": "procedure_list",
      "signature": "ad.procedure_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Procedimentos da filial com especialidade, materiais, preço calculado (fn_pricing_calc; lucro do procedimento > especialidade > filial), preço mínimo, decomposição (cartão, comissão, taxas, IR, lucro), situação do valor cobrado hoje (it_price_status, lucro atual) e alertas (NO_TIME, NO_MATERIAL, MATERIAL_NO_PRICE, PERCENT_TOO_HIGH, PRICE_BELOW_COST, PRICE_BELOW_MIN, PRICE_BELOW_SUGGESTED). Filtros: nr_specialty, vc_search, id_include_inactive; it_tax_regime simula PF x PJ. Devolve também parâmetros e resumo. Exige leitura na tela PRICING.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN",
        "PROCEDURE_LIST_REGIME_INVALID"
      ]
    },
    {
      "name": "procedure_save",
      "signature": "ad.procedure_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) um procedimento (especialidade em nr_specialty, que precisa estar ativa) e, quando materials está presente, substitui seus materiais x quantidades. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "PROCEDURE_ACTION_INVALID",
        "PRICING_BRANCH_REQUIRED",
        "PROCEDURE_FORBIDDEN",
        "PROCEDURE_NAME_REQUIRED",
        "PROCEDURE_NAME_IN_USE",
        "PROCEDURE_CODE_IN_USE",
        "PROCEDURE_MINUTES_INVALID",
        "PROCEDURE_VALUE_INVALID",
        "PROCEDURE_PERCENT_INVALID",
        "PROCEDURE_STATUS_INVALID",
        "PROCEDURE_MATERIALS_INVALID",
        "PROCEDURE_MATERIAL_INVALID",
        "PROCEDURE_QUANTITY_INVALID",
        "PROCEDURE_SPECIALTY_INVALID",
        "PROCEDURE_REQUIRED",
        "PROCEDURE_NOT_FOUND"
      ]
    },
    {
      "name": "procedure_suggest",
      "signature": "ad.procedure_suggest(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Auto complete do cadastro de procedimento: itens do catálogo de referência (procedure_template) da especialidade que a filial ainda não cadastrou e procedimentos já cadastrados (com materiais ativos) para copiar. Filtros: nr_specialty, vc_search; até 200 de cada. Exige leitura na tela PRICING.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN"
      ]
    },
    {
      "name": "appointment_list",
      "signature": "ad.appointment_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Agenda da filial num período de até 62 dias (dt_start..dt_end, no fuso da filial): consultas e compromissos com paciente, profissional (nome e cor), procedimento, situação, quem agendou e, para quem lê o financeiro, o selo it_fin_status (1 atendido sem recebimento, 2 recebimento em aberto, 3 recebido); filtros nr_professionals (compromissos da clínica toda sempre vêm) e id_include_cancelled. Devolve também os alertas de retorno de pacientes no período e o fuso. Exige leitura na tela AGENDA.",
      "errors": [
        "VERSION_MISMATCH",
        "AGENDA_BRANCH_REQUIRED",
        "AGENDA_FORBIDDEN",
        "APPOINTMENT_LIST_PERIOD_INVALID"
      ]
    },
    {
      "name": "appointment_save",
      "signature": "ad.appointment_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou altera parcialmente (U, permissão alterar; inclui mudar a situação) uma consulta ou compromisso. Valida a linha resultante inteira (paciente e profissional ativos na consulta, título no compromisso, período) e o conflito de horário com o mesmo profissional ou a clínica toda (encaixe não bloqueia nem é bloqueado; cancelado/faltou não ocupam; mudar só a situação não checa). Grava event_log sem dados pessoais. Segue as configurações da filial: consultas do mesmo profissional no mesmo horário até o limite e, sem permissão de agendar fora do horário, a consulta precisa caber no horário de atendimento do profissional (encaixe passa por cima). Paciente com conta a receber vencida (od.fn_patient_overdue), conforme it_debt_rule da filial: avisa (devolve debt), só o administrador agenda confirmando com id_debt_override (fica no log) ou bloqueia; encaixe não libera. Também a regra de conta a receber em aberto (it_open_rule), valendo a mais forte.",
      "errors": [
        "VERSION_MISMATCH",
        "APPOINTMENT_ACTION_INVALID",
        "AGENDA_BRANCH_REQUIRED",
        "APPOINTMENT_FORBIDDEN",
        "APPOINTMENT_REQUIRED",
        "APPOINTMENT_NOT_FOUND",
        "APPOINTMENT_VALUE_INVALID",
        "APPOINTMENT_TYPE_INVALID",
        "APPOINTMENT_PATIENT_REQUIRED",
        "APPOINTMENT_PATIENT_INVALID",
        "APPOINTMENT_PROFESSIONAL_REQUIRED",
        "APPOINTMENT_PROFESSIONAL_INVALID",
        "APPOINTMENT_PROCEDURE_INVALID",
        "APPOINTMENT_TITLE_REQUIRED",
        "APPOINTMENT_PERIOD_INVALID",
        "APPOINTMENT_STATUS_INVALID",
        "APPOINTMENT_CONFLICT",
        "APPOINTMENT_OUTSIDE_HOURS",
        "APPOINTMENT_DEBT_BLOCKED",
        "APPOINTMENT_DEBT_APPROVAL",
        "APPOINTMENT_DEBT_CONFIRM",
        "APPOINTMENT_OPEN_BLOCKED",
        "APPOINTMENT_OPEN_APPROVAL",
        "APPOINTMENT_OPEN_CONFIRM"
      ]
    },
    {
      "name": "professional_list",
      "signature": "ad.professional_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Profissionais da filial (colunas da agenda) com cor, intervalo, usuário vinculado e horário de atendimento por dia da semana; devolve também os usuários ativos da empresa para o vínculo. Filtro: id_include_inactive. Exige leitura na tela AGENDA.",
      "errors": [
        "VERSION_MISMATCH",
        "AGENDA_BRANCH_REQUIRED",
        "AGENDA_FORBIDDEN"
      ]
    },
    {
      "name": "professional_save",
      "signature": "ad.professional_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) um profissional: nome, conselho, cor (sem cor = paleta padrão), intervalo, usuário vinculado, situação e, com schedules, substitui o horário de atendimento (faixas por dia sem sobreposição). Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "PROFESSIONAL_ACTION_INVALID",
        "AGENDA_BRANCH_REQUIRED",
        "PROFESSIONAL_FORBIDDEN",
        "PROFESSIONAL_NAME_REQUIRED",
        "PROFESSIONAL_NAME_IN_USE",
        "PROFESSIONAL_COLOR_INVALID",
        "PROFESSIONAL_SLOT_INVALID",
        "PROFESSIONAL_USER_INVALID",
        "PROFESSIONAL_USER_IN_USE",
        "PROFESSIONAL_STATUS_INVALID",
        "PROFESSIONAL_SCHEDULES_INVALID",
        "PROFESSIONAL_SCHEDULE_INVALID",
        "PROFESSIONAL_SCHEDULE_OVERLAP",
        "PROFESSIONAL_REQUIRED",
        "PROFESSIONAL_NOT_FOUND"
      ]
    },
    {
      "name": "specialty_list",
      "signature": "ad.specialty_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Especialidades da filial com o lucro desejado e quantos procedimentos ativos cada uma tem. Filtro: id_include_inactive. Exige leitura na tela PRICING.",
      "errors": [
        "VERSION_MISMATCH",
        "PRICING_BRANCH_REQUIRED",
        "PRICING_FORBIDDEN"
      ]
    },
    {
      "name": "specialty_save",
      "signature": "ad.specialty_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) uma especialidade: nome, lucro desejado (null = padrão da filial) e situação. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "SPECIALTY_ACTION_INVALID",
        "PRICING_BRANCH_REQUIRED",
        "SPECIALTY_FORBIDDEN",
        "SPECIALTY_NAME_REQUIRED",
        "SPECIALTY_NAME_IN_USE",
        "SPECIALTY_PERCENT_INVALID",
        "SPECIALTY_STATUS_INVALID",
        "SPECIALTY_REQUIRED",
        "SPECIALTY_NOT_FOUND"
      ]
    },
    {
      "name": "fin_setup",
      "signature": "ad.fin_setup(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Primeiro uso do financeiro: cria Caixa e Banco, receitas padrão, as despesas a partir das despesas ativas da precificação (com o tipo de custo) e a categoria Comissões, só o que falta. Permissão criar na tela FINANCE. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN"
      ]
    },
    {
      "name": "fin_catalog",
      "signature": "ad.fin_catalog(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cadastros do financeiro: contas com o saldo de hoje, plano de contas (com quantos lançamentos usam cada categoria), fornecedores, taxas de recebimento e a permissão do usuário. Exige leitura na tela FINANCE. As contas trazem banco, agência e número. Categorias trazem it_dre_group.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN"
      ]
    },
    {
      "name": "fin_account_save",
      "signature": "ad.fin_account_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) uma conta: nome, tipo (caixa, banco, cofre), saldo inicial e situação. Grava event_log. Guarda também banco (código e nome), agência e número da conta.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_ACCOUNT_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_ACCOUNT_FORBIDDEN",
        "FIN_ACCOUNT_NAME_REQUIRED",
        "FIN_ACCOUNT_NAME_IN_USE",
        "FIN_ACCOUNT_TYPE_INVALID",
        "FIN_ACCOUNT_VALUE_INVALID",
        "FIN_ACCOUNT_STATUS_INVALID",
        "FIN_ACCOUNT_REQUIRED",
        "FIN_ACCOUNT_NOT_FOUND",
        "FIN_ACCOUNT_BANK_INVALID"
      ]
    },
    {
      "name": "fin_category_save",
      "signature": "ad.fin_category_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) uma categoria do plano de contas: nome, receita/despesa (só na criação), tipo de custo da despesa e situação. Grava event_log. Aceita it_dre_group (grupo no DRE).",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_CATEGORY_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_CATEGORY_FORBIDDEN",
        "FIN_CATEGORY_NAME_REQUIRED",
        "FIN_CATEGORY_NAME_IN_USE",
        "FIN_CATEGORY_KIND_INVALID",
        "FIN_CATEGORY_COST_TYPE_INVALID",
        "FIN_CATEGORY_STATUS_INVALID",
        "FIN_CATEGORY_REQUIRED",
        "FIN_CATEGORY_NOT_FOUND",
        "FIN_CATEGORY_DRE_GROUP_INVALID"
      ]
    },
    {
      "name": "fin_supplier_save",
      "signature": "ad.fin_supplier_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) um fornecedor: nome, CPF/CNPJ, telefone, e-mail, observações e situação (documentos e telefone só com dígitos). Grava event_log sem documento e contato.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_SUPPLIER_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_SUPPLIER_FORBIDDEN",
        "FIN_SUPPLIER_NAME_REQUIRED",
        "FIN_SUPPLIER_NAME_IN_USE",
        "FIN_SUPPLIER_DOCUMENT_INVALID",
        "FIN_SUPPLIER_PHONE_INVALID",
        "FIN_SUPPLIER_EMAIL_INVALID",
        "FIN_SUPPLIER_STATUS_INVALID",
        "FIN_SUPPLIER_REQUIRED",
        "FIN_SUPPLIER_NOT_FOUND"
      ]
    },
    {
      "name": "fin_entry_save",
      "signature": "ad.fin_entry_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria contas a receber/pagar (I: única, parcelada em N meses ou recorrente por N meses; pode nascer paga, entrando no caixa aberto ou, em cartão/boleto/cheque com taxa, gerando recebíveis) ou altera parcialmente um lançamento (U; pago só muda descrição, categoria e observações; cancelado não muda). Aceita o profissional (comissão). Grava event_log sem dados pessoais. Já paga, aceita os dados do cartão/cheque para os recebíveis.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_ENTRY_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_ENTRY_FORBIDDEN",
        "FIN_ENTRY_VALUE_INVALID",
        "FIN_ENTRY_KIND_INVALID",
        "FIN_ENTRY_CATEGORY_INVALID",
        "FIN_ENTRY_ACCOUNT_INVALID",
        "FIN_ENTRY_SUPPLIER_INVALID",
        "FIN_ENTRY_PATIENT_INVALID",
        "FIN_ENTRY_DESCRIPTION_REQUIRED",
        "FIN_ENTRY_AMOUNT_INVALID",
        "FIN_ENTRY_DUE_REQUIRED",
        "FIN_ENTRY_METHOD_INVALID",
        "FIN_ENTRY_INSTALLMENTS_INVALID",
        "FIN_ENTRY_PAID_ACCOUNT_REQUIRED",
        "FIN_ENTRY_REQUIRED",
        "FIN_ENTRY_NOT_FOUND",
        "FIN_ENTRY_PAID_LOCKED",
        "FIN_ENTRY_CANCELLED_LOCKED",
        "FIN_ENTRY_PROFESSIONAL_INVALID",
        "FIN_RECEIVABLE_DETAILS_INVALID"
      ]
    },
    {
      "name": "fin_entry_settle",
      "signature": "ad.fin_entry_settle(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Baixa e situação de um lançamento (permissão alterar): PAY (conta, data, valor e forma; entra no caixa aberto da conta; em cartão/boleto/cheque com taxa vai para Recebíveis e gera os recebíveis, com parcelas do cartão e referência), UNDO (desfaz o pagamento, se o caixa não foi fechado e nenhum recebível foi confirmado), CANCEL (com id_following cancela também as próximas parcelas em aberto) e REOPEN. Grava event_log. No PAY aceita os dados do cartão/cheque, que vão para os recebíveis. Conta a receber: a forma de pagamento precisa estar entre as aceitas da filial; paga com atraso, o valor padrão inclui multa e juros (od.fn_fin_late_charge), devolvidos em late. Receber menos que valor + multa e juros segue it_late_edit (só administrador ou ninguém).",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_ENTRY_FORBIDDEN",
        "FIN_ENTRY_REQUIRED",
        "FIN_ENTRY_NOT_FOUND",
        "FIN_SETTLE_ACTION_INVALID",
        "FIN_SETTLE_STATUS_INVALID",
        "FIN_ENTRY_VALUE_INVALID",
        "FIN_ENTRY_ACCOUNT_INVALID",
        "FIN_ENTRY_AMOUNT_INVALID",
        "FIN_ENTRY_METHOD_INVALID",
        "FIN_CASH_SESSION_CLOSED",
        "FIN_RECEIVABLE_CONFIRMED",
        "FIN_BANK_RECONCILED",
        "FIN_RECEIVABLE_DETAILS_INVALID",
        "FIN_ENTRY_METHOD_NOT_ACCEPTED",
        "FIN_LATE_EDIT_FORBIDDEN",
        "FIN_LATE_EDIT_ADMIN"
      ]
    },
    {
      "name": "fin_entry_list",
      "signature": "ad.fin_entry_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Contas a receber ou a pagar num período (até 400 dias) por situação (em aberto, vencidas, pagas, canceladas, todas), conta, categoria, fornecedor, paciente, profissional e busca; com profissional e atendimento de cada lançamento e totais (em aberto, vencido, pago, por tipo de custo). Exige leitura na tela FINANCE. Filtro pelo vencimento ou pela competência (vc_date) e só parceladas; devolve a regra recorrente de origem e a quantidade de anexos; antes gera as contas recorrentes do período. Contas a receber vencidas em aberto trazem multa e juros até hoje (vl_late_fee, vl_late_interest). Traz o recibo ativo de cada conta (nr_receipt, vc_receipt_number).",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fin_overview",
      "signature": "ad.fin_overview(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Visão geral do financeiro no dia: saldo por conta, a receber e a pagar no dia, vencidos, o mês (recebido, pago, a receber, a pagar), próximos vencimentos e se a filial já foi configurada. Exige leitura na tela FINANCE. Antes gera as contas recorrentes até 12 meses à frente.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fin_cashflow",
      "signature": "ad.fin_cashflow(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Fluxo de caixa de um mês, dia a dia: realizado (pago) e previsto (em aberto; vencidos antes do mês entram no dia 1), saldo acumulado realizado e projetado a partir do saldo anterior. Exige leitura na tela FINANCE. Antes gera as contas recorrentes do mês consultado.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fin_statement",
      "signature": "ad.fin_statement(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Extrato de uma conta (ou de todas as ativas) no período: saldo inicial, movimentos pagos e transferências entre contas com o saldo após cada um, entradas, saídas e saldo final. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fn_fin_balance",
      "signature": "od.fn_fin_balance(p_nr_company bigint, p_nr_branch bigint, p_nr_account bigint, p_dt_before date)",
      "kind": "helper",
      "grant": "interna",
      "description": "Saldo realizado de uma conta (ou de todas as ativas, com p_nr_account nulo) antes de p_dt_before: saldo inicial + receitas pagas − despesas pagas + transferências recebidas − enviadas (sem data = tudo até agora)."
    },
    {
      "name": "appointment_checkout_get",
      "signature": "ad.appointment_checkout_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Dados do fechamento financeiro de uma consulta (leitura na tela FINANCE): paciente, profissional, procedimento com o valor cobrado e a comissão efetiva, lançamentos já gerados pelo atendimento, receita padrão, contas ativas e a conta do caixa aberto do usuário.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "CHECKOUT_APPOINTMENT_REQUIRED",
        "CHECKOUT_APPOINTMENT_NOT_FOUND"
      ]
    },
    {
      "name": "appointment_checkout",
      "signature": "ad.appointment_checkout(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Fecha financeiramente a consulta (criar na tela FINANCE): conta a receber do paciente em 1 a 24 parcelas (a 1ª pode ser recebida na hora, no caixa aberto ou em cartão/boleto/cheque gerando recebíveis), comissão do profissional a pagar no dia 10 do mês seguinte (categoria Comissões) e marca a consulta como atendida. Um fechamento ativo por atendimento. Grava event_log sem dados pessoais. Aceita os dados do cartão/cheque para os recebíveis. A forma de pagamento precisa estar entre as aceitas da filial.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_ENTRY_FORBIDDEN",
        "CHECKOUT_APPOINTMENT_REQUIRED",
        "CHECKOUT_APPOINTMENT_NOT_FOUND",
        "CHECKOUT_APPOINTMENT_INVALID",
        "CHECKOUT_ALREADY_DONE",
        "CHECKOUT_NOT_CONFIGURED",
        "FIN_ENTRY_VALUE_INVALID",
        "FIN_ENTRY_AMOUNT_INVALID",
        "FIN_ENTRY_CATEGORY_INVALID",
        "FIN_ENTRY_INSTALLMENTS_INVALID",
        "FIN_ENTRY_METHOD_INVALID",
        "FIN_ENTRY_PAID_ACCOUNT_REQUIRED",
        "CHECKOUT_COMMISSION_INVALID",
        "FIN_RECEIVABLE_DETAILS_INVALID",
        "FIN_ENTRY_METHOD_NOT_ACCEPTED"
      ]
    },
    {
      "name": "fin_cash_open",
      "signature": "ad.fin_cash_open(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Abre o caixa do dia do usuário numa conta do tipo caixa (criar na tela FINANCE), com o valor contado (padrão: saldo atual). Uma sessão aberta por conta e por usuário. Grava event_log. Não abre com o caixa desligado nas configurações.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_CASH_FORBIDDEN",
        "FIN_CASH_VALUE_INVALID",
        "FIN_CASH_ACCOUNT_INVALID",
        "FIN_CASH_ACCOUNT_IN_USE",
        "FIN_CASH_USER_HAS_OPEN",
        "FIN_CASH_DISABLED"
      ]
    },
    {
      "name": "fin_cash_close",
      "signature": "ad.fin_cash_close(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Fecha uma sessão de caixa com o valor contado; grava o esperado (saldo da conta) e a diferença. O dono fecha com criar; fechar o caixa de outra pessoa exige alterar. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_CASH_FORBIDDEN",
        "FIN_CASH_VALUE_INVALID",
        "FIN_CASH_SESSION_NOT_FOUND",
        "FIN_CASH_SESSION_CLOSED"
      ]
    },
    {
      "name": "fin_dre",
      "signature": "ad.fin_dre(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "DRE gerencial mês a mês (até 24 meses) pelo plano de contas: receita bruta por categoria, impostos sobre a receita (estimados pela alíquota da filial), receita líquida, custos variáveis, margem de contribuição, custos fixos, outras despesas, resultado antes dos impostos, IRPJ e CSLL estimados, resultado líquido e investimentos (fora do resultado). Por competência (padrão) ou por caixa (pagos, pelo mês do pagamento). Exige ler na tela FINANCE. Categorias com grupo escolhido (it_dre_group) vão para ele: deduções, receitas e despesas não operacionais.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_DRE_PERIOD_INVALID"
      ]
    },
    {
      "name": "fn_dre_cat_lines",
      "signature": "ad.fn_dre_cat_lines(p_cats jsonb, p_group integer, p_sign integer, p_gross numeric)",
      "kind": "helper",
      "grant": "interna",
      "description": "Linhas de categoria de um grupo do DRE."
    },
    {
      "name": "fn_dre_line",
      "signature": "ad.fn_dre_line(p_key text, p_label text, p_level integer, p_sign integer, p_estimated boolean, p_values numeric[], p_gross numeric)",
      "kind": "helper",
      "grant": "interna",
      "description": "Uma linha do DRE (array jsonb de um elemento): valores por mês, total e percentual sobre a receita bruta."
    },
    {
      "name": "fin_cash_status",
      "signature": "ad.fin_cash_status(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Caixa do dia (leitura na tela FINANCE): o caixa aberto do usuário, as contas caixa com quem está com cada uma e as últimas sessões, cada uma com abertura, entradas por forma de pagamento, saídas, sangrias/suprimentos, esperado, contado e diferença. Devolve id_enabled (caixa ligado nas configurações).",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN"
      ]
    },
    {
      "name": "fin_transfer_save",
      "signature": "ad.fin_transfer_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Transferência entre contas, sangria ou suprimento (I, criar) e cancelamento (CANCEL, alterar; não vale com o caixa da sessão fechado). Entra no caixa aberto da conta caixa envolvida. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_TRANSFER_ACTION_INVALID",
        "FIN_TRANSFER_FORBIDDEN",
        "FIN_TRANSFER_VALUE_INVALID",
        "FIN_TRANSFER_TYPE_INVALID",
        "FIN_TRANSFER_ACCOUNT_INVALID",
        "FIN_TRANSFER_SAME_ACCOUNT",
        "FIN_TRANSFER_AMOUNT_INVALID",
        "FIN_TRANSFER_REQUIRED",
        "FIN_TRANSFER_NOT_FOUND",
        "FIN_TRANSFER_STATUS_INVALID",
        "FIN_CASH_SESSION_CLOSED",
        "FIN_BANK_RECONCILED"
      ]
    },
    {
      "name": "fn_procedure_min_price",
      "signature": "od.fn_procedure_min_price(p_nr_company bigint, p_nr_branch bigint, p_nr_procedure bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Preço mínimo (lucro zero) de um procedimento pela fórmula da precificação, sem exigir a tela PRICING; usado na regra de orçamento abaixo do mínimo."
    },
    {
      "name": "fn_anamnesis_default",
      "signature": "od.fn_anamnesis_default(p_nr_company bigint, p_nr_branch bigint, p_nr_user bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Cria o modelo de anamnese Geral (16 perguntas usuais, com alertas de saúde) quando a filial ainda não tem modelo; usado por anamnesis_model_list."
    },
    {
      "name": "fn_document_default",
      "signature": "od.fn_document_default(p_nr_company bigint, p_nr_branch bigint, p_nr_user bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Cria os modelos de documento padrão (atestado, receituário, declaração de comparecimento, contrato e termo de consentimento) quando a filial ainda não tem modelo; usado por document_template_list."
    },
    {
      "name": "fn_document_render",
      "signature": "od.fn_document_render(p_nr_company bigint, p_nr_branch bigint, p_nr_patient bigint, p_nr_professional bigint, p_body text, p_extra jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Preenche os campos {{...}} de um texto com os dados do paciente, do profissional, da clínica, a data no fuso da filial e os extras (dias, cid, hora_inicio, hora_fim, valor, texto)."
    },
    {
      "name": "fn_medication_default",
      "signature": "od.fn_medication_default(p_nr_company bigint, p_nr_branch bigint, p_nr_user bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Cria a lista inicial de 30 medicamentos usuais na odontologia com posologia de referência quando a filial ainda não tem nenhum; usado por medication_list."
    },
    {
      "name": "fn_fin_open_session",
      "signature": "od.fn_fin_open_session(p_nr_company bigint, p_nr_branch bigint, p_nr_account bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Sessão de caixa aberta na conta (ou nula): o pagamento feito nessa conta entra no fechamento dela."
    },
    {
      "name": "fn_fin_late_charge",
      "signature": "od.fn_fin_late_charge(p_nr_company bigint, p_nr_branch bigint, p_vl_amount numeric, p_dt_due date, p_dt_ref date)",
      "kind": "helper",
      "grant": "interna",
      "description": "Multa (pc_late_fee, uma vez) e juros de mora (pc_late_interest ao mês, pro rata por dia) de uma conta a receber na data de referência; zero sem atraso ou sem configuração. Devolve {qt_days, vl_fine, vl_interest, vl_total}."
    },
    {
      "name": "fn_patient_overdue",
      "signature": "od.fn_patient_overdue(p_nr_company bigint, p_nr_branch bigint, p_nr_patient bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Contas a receber do paciente em aberto vencidas há mais que a tolerância da filial (qt_debt_days), com hoje no fuso da filial. Devolve {qt_entries, vl_total}."
    },
    {
      "name": "fn_fin_category_ensure",
      "signature": "od.fn_fin_category_ensure(p_nr_company bigint, p_nr_branch bigint, p_vc_name text, p_it_kind smallint, p_it_cost_type smallint, p_nr_user bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Categoria do plano de contas pelo nome e tipo; cria (ou reativa) quando falta. Usada para Comissões e para a receita padrão do fechamento."
    },
    {
      "name": "fin_rate_save",
      "signature": "ad.fin_rate_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, criar) ou altera parcialmente (U, alterar) uma taxa de recebimento: nome, forma (crédito, débito, boleto, cheque), faixa de parcelas, percentual, tarifa fixa, prazo e conta destino. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_RATE_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_RATE_FORBIDDEN",
        "FIN_RATE_REQUIRED",
        "FIN_RATE_NOT_FOUND",
        "FIN_RATE_VALUE_INVALID",
        "FIN_RATE_NAME_REQUIRED",
        "FIN_RATE_NAME_IN_USE",
        "FIN_RATE_METHOD_INVALID",
        "FIN_RATE_INSTALLMENTS_INVALID",
        "FIN_RATE_FEE_INVALID",
        "FIN_RATE_DAYS_INVALID",
        "FIN_RATE_ACCOUNT_INVALID",
        "FIN_RATE_STATUS_INVALID"
      ]
    },
    {
      "name": "fin_receivable_settle",
      "signature": "ad.fin_receivable_settle(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Confirma (CONFIRM: data e valor que caiu; transfere de Recebíveis para a conta destino e lança a taxa real como despesa) ou desfaz (UNDO) um recebível. Permissão alterar na tela FINANCE. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_RECEIVABLE_FORBIDDEN",
        "FIN_RECEIVABLE_REQUIRED",
        "FIN_RECEIVABLE_NOT_FOUND",
        "FIN_RECEIVABLE_ACTION_INVALID",
        "FIN_RECEIVABLE_STATUS_INVALID",
        "FIN_RECEIVABLE_VALUE_INVALID",
        "FIN_RECEIVABLE_ACCOUNT_INVALID"
      ]
    },
    {
      "name": "fin_receivable_list",
      "signature": "ad.fin_receivable_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Recebíveis com previsão no período (até 400 dias) por situação (a receber, vencidos, recebidos, cancelados) e forma, com paciente, taxa, conta destino e totais bruto, taxa e líquido. Exige leitura na tela FINANCE. Traz os dados do cartão e do cheque.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fin_health_export",
      "signature": "ad.fin_health_export(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Recebimentos de pacientes no período (até 366 dias) para a Receita Saúde: data, valor, paciente e CPF (ou responsável legal), profissional, quantos ficaram sem CPF e o CNPJ da empresa; o app gera o CSV. Exige leitura na tela FINANCE; grava event_log sem dados pessoais. Cada pagamento guarda quando foi exportado: filtro pendentes/exportados, escolha das linhas (nr_entries) e, com id_mark (permissão de alterar), marca as linhas como exportadas.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fn_fin_receivable_make",
      "signature": "od.fn_fin_receivable_make(p_nr_company bigint, p_nr_branch bigint, p_nr_entry bigint, p_qt_installments integer, p_vc_reference text, p_nr_user bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Depois da baixa de uma conta a receber em cartão/boleto/cheque com taxa ativa: leva o valor para a conta de passagem Recebíveis (criada se faltar) e cria um recebível por parcela do cartão com bruto, taxa, líquido e previsão. Sem taxa não faz nada."
    },
    {
      "name": "health_plan_save",
      "signature": "ad.health_plan_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, criar) ou altera parcialmente (U, alterar) um convênio: nome, ANS, CNPJ, prazo de repasse, conta e situação; com prices substitui a tabela de preço por procedimento. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "HEALTH_PLAN_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "HEALTH_PLAN_FORBIDDEN",
        "HEALTH_PLAN_REQUIRED",
        "HEALTH_PLAN_NOT_FOUND",
        "HEALTH_PLAN_VALUE_INVALID",
        "HEALTH_PLAN_NAME_REQUIRED",
        "HEALTH_PLAN_NAME_IN_USE",
        "HEALTH_PLAN_ANS_INVALID",
        "HEALTH_PLAN_DOCUMENT_INVALID",
        "HEALTH_PLAN_DAYS_INVALID",
        "HEALTH_PLAN_ACCOUNT_INVALID",
        "HEALTH_PLAN_STATUS_INVALID",
        "HEALTH_PLAN_PRICES_INVALID",
        "HEALTH_PLAN_PRICE_INVALID"
      ]
    },
    {
      "name": "health_plan_list",
      "signature": "ad.health_plan_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Convênios da filial com a tabela de preço (e o valor particular para comparar), conta do repasse e guias abertas e faturadas, mais os procedimentos e profissionais ativos para os formulários. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN"
      ]
    },
    {
      "name": "health_guide_save",
      "signature": "ad.health_guide_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, criar) ou altera parcialmente (U, alterar) uma guia aberta: convênio, paciente, profissional, atendimento, números, data e itens (valor da tabela do convênio quando não informado). Grava event_log sem dados pessoais.",
      "errors": [
        "VERSION_MISMATCH",
        "HEALTH_GUIDE_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "HEALTH_GUIDE_FORBIDDEN",
        "HEALTH_GUIDE_REQUIRED",
        "HEALTH_GUIDE_NOT_FOUND",
        "HEALTH_GUIDE_LOCKED",
        "HEALTH_GUIDE_VALUE_INVALID",
        "HEALTH_GUIDE_PLAN_INVALID",
        "HEALTH_GUIDE_PATIENT_INVALID",
        "HEALTH_GUIDE_PROFESSIONAL_INVALID",
        "HEALTH_GUIDE_APPOINTMENT_INVALID",
        "HEALTH_GUIDE_DATE_REQUIRED",
        "HEALTH_GUIDE_ITEMS_REQUIRED",
        "HEALTH_GUIDE_ITEM_INVALID",
        "HEALTH_GUIDE_PRICE_REQUIRED"
      ]
    },
    {
      "name": "health_guide_settle",
      "signature": "ad.health_guide_settle(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Ciclo das guias (alterar na tela FINANCE): INVOICE fatura uma ou várias do mesmo convênio numa conta a receber (categoria Convênios, vence no prazo do convênio), UNINVOICE desfaz, PAY registra o pago e a glosa por item (com todas as guias do faturamento pagas, baixa a conta; glosa total cancela), UNPAY desfaz e CANCEL cancela a aberta. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "HEALTH_GUIDE_FORBIDDEN",
        "HEALTH_GUIDE_SETTLE_ACTION_INVALID",
        "HEALTH_GUIDE_REQUIRED",
        "HEALTH_GUIDE_NOT_FOUND",
        "HEALTH_GUIDE_STATUS_INVALID",
        "HEALTH_GUIDE_PLAN_MIXED",
        "HEALTH_GUIDE_EMPTY",
        "HEALTH_GUIDE_VALUE_INVALID",
        "HEALTH_GUIDE_ACCOUNT_REQUIRED",
        "HEALTH_GUIDE_ENTRY_PAID",
        "FIN_CASH_SESSION_CLOSED",
        "FIN_BANK_RECONCILED"
      ]
    },
    {
      "name": "health_guide_list",
      "signature": "ad.health_guide_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Guias com atendimento no período (até 400 dias) por convênio e situação, com paciente, profissional, itens, vencimento do faturamento, pago e glosa, e os totais. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fin_bank_import",
      "signature": "ad.fin_bank_import(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Importa as linhas do extrato do banco (o app lê o OFX) para uma conta (criar na tela FINANCE); o FITID evita duplicar; com id_auto concilia as que têm uma única sugestão no mesmo dia. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_BANK_FORBIDDEN",
        "FIN_BANK_ACCOUNT_INVALID",
        "FIN_BANK_LINES_INVALID",
        "FIN_BANK_LINE_INVALID"
      ]
    },
    {
      "name": "fin_bank_list",
      "signature": "ad.fin_bank_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Conciliação de uma conta no período: linhas do banco (pendentes com sugestões, conciliadas, ignoradas), movimentos do sistema que ainda não apareceram no banco e totais. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID",
        "FIN_BANK_ACCOUNT_INVALID"
      ]
    },
    {
      "name": "fin_bank_reconcile",
      "signature": "ad.fin_bank_reconcile(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Concilia uma linha do extrato: MATCH (alterar) liga a um lançamento pago ou transferência de mesmo valor na conta, CREATE (criar) lança receita/despesa paga a partir da linha, IGNORE e UNDO (alterar). Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_BANK_FORBIDDEN",
        "FIN_BANK_ACTION_INVALID",
        "FIN_BANK_LINE_REQUIRED",
        "FIN_BANK_LINE_NOT_FOUND",
        "FIN_BANK_STATUS_INVALID",
        "FIN_BANK_MATCH_INVALID",
        "FIN_BANK_CATEGORY_INVALID",
        "FIN_ENTRY_SUPPLIER_INVALID"
      ]
    },
    {
      "name": "fn_fin_bank_candidates",
      "signature": "od.fn_fin_bank_candidates(p_nr_company bigint, p_nr_branch bigint, p_nr_line bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Até 5 sugestões para uma linha pendente do extrato: lançamentos pagos e transferências da mesma conta, mesmo valor com sinal, até 5 dias de diferença e ainda não conciliados."
    },
    {
      "name": "fin_recurrence_save",
      "signature": "ad.fin_recurrence_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Conta recorrente como regra (todo mês no dia X, sem data final ou até uma data): I cria e já gera 12 meses; U altera e os futuros em aberto acompanham (data final menor cancela os que passaram dela); CANCEL encerra e cancela os futuros em aberto. Permissão criar/alterar na tela FINANCE. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_RECURRENCE_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_RECURRENCE_FORBIDDEN",
        "FIN_RECURRENCE_REQUIRED",
        "FIN_RECURRENCE_NOT_FOUND",
        "FIN_RECURRENCE_CANCELLED",
        "FIN_RECURRENCE_VALUE_INVALID",
        "FIN_ENTRY_KIND_INVALID",
        "FIN_ENTRY_CATEGORY_INVALID",
        "FIN_ENTRY_ACCOUNT_INVALID",
        "FIN_ENTRY_SUPPLIER_INVALID",
        "FIN_ENTRY_PATIENT_INVALID",
        "FIN_ENTRY_DESCRIPTION_REQUIRED",
        "FIN_ENTRY_AMOUNT_INVALID",
        "FIN_ENTRY_METHOD_INVALID",
        "FIN_RECURRENCE_DAY_INVALID",
        "FIN_RECURRENCE_PERIOD_INVALID"
      ]
    },
    {
      "name": "fin_recurrence_list",
      "signature": "ad.fin_recurrence_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Contas recorrentes da filial (a receber/a pagar), com o próximo vencimento em aberto e quantos já foram pagos; antes completa os lançamentos até 12 meses à frente. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN"
      ]
    },
    {
      "name": "fin_receipt_issue",
      "signature": "ad.fin_receipt_issue(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Emite o recibo de uma conta a receber paga (criar na tela FINANCE) com o próximo número da filial; se já existe recibo ativo devolve o mesmo (id_existing). Pagador padrão: o paciente (nome e CPF); descrição padrão: a da conta. Devolve recibo e emitente. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_RECEIPT_FORBIDDEN",
        "FIN_ENTRY_REQUIRED",
        "FIN_ENTRY_NOT_FOUND",
        "FIN_RECEIPT_NOT_PAID",
        "FIN_RECEIPT_PAYER_REQUIRED",
        "FIN_RECEIPT_DOCUMENT_INVALID"
      ]
    },
    {
      "name": "fin_receipt_get",
      "signature": "ad.fin_receipt_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Um recibo (por número ou o ativo da conta) com os dados da clínica emitente (razão social, CNPJ, endereço, responsável técnico) para o PDF. Exige ler na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_RECEIPT_NOT_FOUND"
      ]
    },
    {
      "name": "fin_receipt_cancel",
      "signature": "ad.fin_receipt_cancel(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cancela um recibo emitido com o motivo (alterar na tela FINANCE); o número não é reaproveitado. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_RECEIPT_FORBIDDEN",
        "FIN_RECEIPT_NOT_FOUND",
        "FIN_RECEIPT_REASON_REQUIRED"
      ]
    },
    {
      "name": "anamnesis_model_list",
      "signature": "ad.anamnesis_model_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Modelos de anamnese da filial com as perguntas (cria o modelo Geral na primeira chamada). Exige ler na tela PATIENTS ou SETTINGS; permission.id_update = pode editar (alterar em SETTINGS).",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN"
      ]
    },
    {
      "name": "anamnesis_model_save",
      "signature": "ad.anamnesis_model_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) um modelo de anamnese: nome, especialidade, situação e as perguntas (substituídas inteiras). Exige alterar na tela SETTINGS. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "ANAMNESIS_MODEL_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "ANAMNESIS_MODEL_FORBIDDEN",
        "ANAMNESIS_MODEL_NOT_FOUND",
        "ANAMNESIS_MODEL_NAME_REQUIRED",
        "ANAMNESIS_MODEL_SPECIALTY_INVALID",
        "ANAMNESIS_MODEL_QUESTIONS_REQUIRED",
        "ANAMNESIS_QUESTION_INVALID",
        "ANAMNESIS_MODEL_VALUE_INVALID"
      ]
    },
    {
      "name": "patient_anamnesis_save",
      "signature": "ad.patient_anamnesis_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Preenche (I, criar ou alterar) ou exclui (D, alterar) uma anamnese do paciente na tela PATIENTS: copia as perguntas do modelo e grava as respostas; \"sim\" em pergunta de alerta vira alerta. Grava event_log sem as respostas.",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_ANAMNESIS_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "PATIENT_ANAMNESIS_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "ANAMNESIS_MODEL_NOT_FOUND",
        "PATIENT_ANAMNESIS_VALUE_INVALID",
        "PATIENT_ANAMNESIS_NOT_FOUND"
      ]
    },
    {
      "name": "clinical_evolution_save",
      "signature": "ad.clinical_evolution_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Registra (I, criar ou alterar) ou exclui (D, alterar) uma evolução clínica na tela PATIENTS; com nr_budget/nr_item marca o item do orçamento aprovado como realizado (e a exclusão desmarca). Grava event_log sem o texto.",
      "errors": [
        "VERSION_MISMATCH",
        "CLINICAL_EVOLUTION_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "CLINICAL_EVOLUTION_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "CLINICAL_EVOLUTION_TEXT_REQUIRED",
        "CLINICAL_EVOLUTION_VALUE_INVALID",
        "CLINICAL_EVOLUTION_PROFESSIONAL_INVALID",
        "CLINICAL_EVOLUTION_PROCEDURE_INVALID",
        "CLINICAL_EVOLUTION_ITEM_INVALID",
        "CLINICAL_EVOLUTION_NOT_FOUND"
      ]
    },
    {
      "name": "tooth_mark_save",
      "signature": "ad.tooth_mark_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Marca (I, criar ou alterar), altera parcialmente (U) ou remove (D) uma marcação do odontograma na tela PATIENTS: dente FDI, condição, faces, situação. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "TOOTH_MARK_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "TOOTH_MARK_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "TOOTH_MARK_TOOTH_INVALID",
        "TOOTH_MARK_VALUE_INVALID",
        "TOOTH_MARK_NOT_FOUND"
      ]
    },
    {
      "name": "patient_record_get",
      "signature": "ad.patient_record_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Prontuário do paciente (ler na tela PATIENTS): alertas da anamnese mais recente, anamneses com respostas, evoluções, odontograma, itens de orçamento aprovado a fazer e realizados, e permissões.",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND"
      ]
    },
    {
      "name": "document_template_list",
      "signature": "ad.document_template_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Modelos de documento da filial (cria os padrão na primeira chamada) e os campos {{...}} disponíveis. Exige ler na tela PATIENTS ou SETTINGS; permission.id_update = edita (alterar em SETTINGS).",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN"
      ]
    },
    {
      "name": "document_template_save",
      "signature": "ad.document_template_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) um modelo de documento: tipo, nome, texto e situação. Exige alterar na tela SETTINGS. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "DOCUMENT_TEMPLATE_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "DOCUMENT_TEMPLATE_FORBIDDEN",
        "DOCUMENT_TEMPLATE_NOT_FOUND",
        "DOCUMENT_TEMPLATE_NAME_REQUIRED",
        "DOCUMENT_TEMPLATE_BODY_REQUIRED",
        "DOCUMENT_TEMPLATE_VALUE_INVALID"
      ]
    },
    {
      "name": "medication_list",
      "signature": "ad.medication_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Catálogo de medicamentos da filial com busca (cria a lista inicial na primeira chamada). Exige ler na tela PATIENTS ou SETTINGS; permission.id_update = edita (alterar em SETTINGS).",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN"
      ]
    },
    {
      "name": "medication_save",
      "signature": "ad.medication_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou altera parcialmente (U) um medicamento do catálogo (inativar = it_status 90). Exige alterar na tela SETTINGS. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "MEDICATION_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "MEDICATION_FORBIDDEN",
        "MEDICATION_NOT_FOUND",
        "MEDICATION_NAME_REQUIRED",
        "MEDICATION_VALUE_INVALID"
      ]
    },
    {
      "name": "patient_document_render",
      "signature": "ad.patient_document_render(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Pré-visualização de um documento: preenche os campos {{...}} do modelo ou do texto com os dados do paciente, do profissional, da clínica e os extras (dias, CID, horários, valor, texto). Não grava. Exige ler na tela PATIENTS.",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "DOCUMENT_TEMPLATE_NOT_FOUND",
        "PATIENT_DOCUMENT_PROFESSIONAL_INVALID"
      ]
    },
    {
      "name": "patient_document_save",
      "signature": "ad.patient_document_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Emite (I, criar ou alterar) ou exclui (D, alterar) um documento do paciente na tela PATIENTS: guarda o texto final e, no receituário, os medicamentos (completados pelo catálogo). Grava event_log sem o texto.",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_DOCUMENT_ACTION_INVALID",
        "RECORD_BRANCH_REQUIRED",
        "PATIENT_DOCUMENT_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "PATIENT_DOCUMENT_VALUE_INVALID",
        "PATIENT_DOCUMENT_TITLE_REQUIRED",
        "PATIENT_DOCUMENT_BODY_REQUIRED",
        "PATIENT_DOCUMENT_ITEMS_REQUIRED",
        "PATIENT_DOCUMENT_ITEM_INVALID",
        "DOCUMENT_TEMPLATE_NOT_FOUND",
        "PATIENT_DOCUMENT_PROFESSIONAL_INVALID",
        "PATIENT_DOCUMENT_NOT_FOUND"
      ]
    },
    {
      "name": "patient_document_list",
      "signature": "ad.patient_document_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Documentos emitidos do paciente (ler na tela PATIENTS) com os medicamentos, o paciente e o emitente para o PDF, e as permissões.",
      "errors": [
        "VERSION_MISMATCH",
        "RECORD_BRANCH_REQUIRED",
        "RECORD_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND"
      ]
    },
    {
      "name": "budget_list",
      "signature": "ad.budget_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Orçamentos da filial ou de um paciente, por situação (em aberto, aguardando, aprovados, recusados, cancelados, vencidos) e período, com busca e totais. Exige ler na tela BUDGETS.",
      "errors": [
        "VERSION_MISMATCH",
        "BUDGET_BRANCH_REQUIRED",
        "BUDGET_FORBIDDEN",
        "BUDGET_FILTER_INVALID"
      ]
    },
    {
      "name": "budget_get",
      "signature": "ad.budget_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Um orçamento com itens, contas a receber geradas, paciente, emitente (para o PDF), desconto máximo da filial e permissões. Exige ler na tela BUDGETS.",
      "errors": [
        "VERSION_MISMATCH",
        "BUDGET_BRANCH_REQUIRED",
        "BUDGET_FORBIDDEN",
        "BUDGET_NOT_FOUND"
      ]
    },
    {
      "name": "budget_save",
      "signature": "ad.budget_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, criar) ou altera parcialmente (U, alterar) um orçamento em aberto/aguardando: itens (procedimento ou livre; valor padrão = valor cobrado hoje), desconto em valor ou %, validade, condição de pagamento. Desconto acima do máximo: o administrador já aprova; os demais deixam aguardando. Grava event_log sem dados pessoais. Item abaixo do preço mínimo da precificação também precisa do administrador (ou é recusado); a redução do valor cobrado pode contar como desconto; sem pedido de aprovação, desconto acima do máximo é recusado.",
      "errors": [
        "VERSION_MISMATCH",
        "BUDGET_ACTION_INVALID",
        "BUDGET_BRANCH_REQUIRED",
        "BUDGET_FORBIDDEN",
        "BUDGET_REQUIRED",
        "BUDGET_NOT_FOUND",
        "BUDGET_STATUS_INVALID",
        "BUDGET_VALUE_INVALID",
        "BUDGET_PATIENT_INVALID",
        "BUDGET_PROFESSIONAL_INVALID",
        "BUDGET_DATE_INVALID",
        "BUDGET_ITEMS_REQUIRED",
        "BUDGET_ITEM_INVALID",
        "BUDGET_PROCEDURE_INVALID",
        "BUDGET_DISCOUNT_INVALID",
        "BUDGET_DISCOUNT_OVER_MAX",
        "BUDGET_BELOW_MIN"
      ]
    },
    {
      "name": "budget_status",
      "signature": "ad.budget_status(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Situação do orçamento (alterar na tela BUDGETS): APPROVE_DISCOUNT (só o administrador), ACCEPT (paciente aprovou dentro da validade: gera as contas a receber parceladas na categoria Tratamentos), REFUSE, CANCEL (aprovado só sem pagamento; cancela as contas em aberto) e REOPEN. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "BUDGET_BRANCH_REQUIRED",
        "BUDGET_FORBIDDEN",
        "BUDGET_REQUIRED",
        "BUDGET_NOT_FOUND",
        "BUDGET_ACTION_INVALID",
        "BUDGET_STATUS_INVALID",
        "BUDGET_DISCOUNT_FORBIDDEN",
        "BUDGET_EXPIRED",
        "BUDGET_VALUE_INVALID",
        "BUDGET_EMPTY",
        "BUDGET_HAS_PAYMENTS",
        "BUDGET_BELOW_MIN"
      ]
    },
    {
      "name": "fin_attachment_save",
      "signature": "ad.fin_attachment_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Registro dos anexos de uma conta, chamado pela Edge Function fin-attachment com o JWT do usuário antes da URL assinada: I reserva o caminho no Storage (PDF ou imagem, até 10 MB; conta não cancelada); DELETE exclui (lógico) e devolve o caminho para apagar o arquivo. Permissão de alterar na tela FINANCE. Grava event_log.",
      "errors": [
        "VERSION_MISMATCH",
        "FIN_ATTACHMENT_ACTION_INVALID",
        "FINANCE_BRANCH_REQUIRED",
        "FIN_ATTACHMENT_FORBIDDEN",
        "FIN_ENTRY_REQUIRED",
        "FIN_ENTRY_NOT_FOUND",
        "FIN_ENTRY_CANCELLED_LOCKED",
        "FIN_ATTACHMENT_VALUE_INVALID",
        "FIN_ATTACHMENT_TYPE_INVALID",
        "FIN_ATTACHMENT_TOO_LARGE",
        "FIN_ATTACHMENT_REQUIRED",
        "FIN_ATTACHMENT_NOT_FOUND"
      ]
    },
    {
      "name": "fin_attachment_list",
      "signature": "ad.fin_attachment_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Anexos ativos de uma conta (ou um só) com o caminho no Storage; usada pelo app e pela Edge Function fin-attachment para o download. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "appointment_pending_checkout",
      "signature": "ad.appointment_pending_checkout(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Consultas do período que já aconteceram e ainda não foram fechadas no financeiro (sem conta a receber ligada e sem guia de convênio; fora faltas e canceladas), para a aba A receber. Exige leitura na tela FINANCE.",
      "errors": [
        "VERSION_MISMATCH",
        "FINANCE_BRANCH_REQUIRED",
        "FINANCE_FORBIDDEN",
        "FIN_LIST_FILTER_INVALID"
      ]
    },
    {
      "name": "fn_fin_recurrence_fill",
      "signature": "od.fn_fin_recurrence_fill(p_company bigint, p_branch bigint, p_until date)",
      "kind": "helper",
      "grant": "interna",
      "description": "Gera os lançamentos das contas recorrentes ativas da filial até o mês de p_until (um por mês, no dia da regra, entre dt_start e dt_end); guarda até onde gerou, então não duplica. Chamada por fin_recurrence_save/list, fin_entry_list, fin_overview e fin_cashflow."
    },
    {
      "name": "fn_fin_receivable_details",
      "signature": "od.fn_fin_receivable_details(p_nr_company bigint, p_nr_branch bigint, p_nr_entry bigint, p_json jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Grava nos recebíveis em aberto de um pagamento os dados do cartão (bandeira, 4 dígitos, autorização, titular e CPF) e do cheque (banco, número) que vieram no JSON da RPC.",
      "errors": [
        "FIN_RECEIVABLE_DETAILS_INVALID"
      ]
    },
    {
      "name": "user_password_reset_check",
      "signature": "ad.user_password_reset_check(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Checagem antes de o administrador da empresa definir uma senha nova para um usuário dela (a troca no Auth é da Edge Function user-password-reset). Exige administrador da empresa e usuário vinculado a ela; conta compartilhada com outra empresa ou administrador da plataforma só troca a própria senha. Devolve o id da conta no Auth e grava event_log (sem a senha).",
      "errors": [
        "VERSION_MISMATCH",
        "USER_PASSWORD_COMPANY_REQUIRED",
        "USER_PASSWORD_FORBIDDEN",
        "COMPANY_USER_USER_REQUIRED",
        "COMPANY_USER_NOT_FOUND",
        "USER_PASSWORD_SHARED"
      ]
    },
    {
      "name": "settings_get",
      "signature": "ad.settings_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Configurações da filial: dados da clínica, preferências da agenda e do cadastro de pacientes (padrões quando não há linha) e horário de funcionamento. Qualquer usuário com acesso à filial lê; devolve se pode alterar (tela SETTINGS) e se pode alterar os dados da clínica (administrador). Inclui as regras do financeiro: bloqueio de inadimplentes e tolerância, caixa ligado, formas aceitas, multa e juros. Inclui as alíquotas do DRE. Inclui o prefixo e o próximo número dos recibos. Inclui security.it_mfa_policy (2FA da empresa). Inclui o desconto máximo e a validade padrão dos orçamentos. Inclui as regras de orçamento, de conta em aberto e de edição de multa e juros.",
      "errors": [
        "VERSION_MISMATCH",
        "SETTINGS_BRANCH_REQUIRED",
        "SETTINGS_FORBIDDEN"
      ]
    },
    {
      "name": "settings_save",
      "signature": "ad.settings_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Grava as preferências da filial (update parcial; cria a linha na primeira vez) e, com hours, substitui o horário de funcionamento. Permissão de alterar na tela SETTINGS. Grava event_log. Também grava bloqueio de inadimplentes (it_debt_rule, qt_debt_days), caixa do dia, formas de pagamento aceitas, multa e juros. vc_patient_required define os campos obrigatórios do cadastro do paciente. Também grava as alíquotas do DRE (pc_dre_revenue_tax, pc_dre_income_tax, pc_dre_csll). Também grava o prefixo e o próximo número dos recibos. Também grava o desconto máximo e a validade padrão dos orçamentos. Também grava as regras de orçamento, conta em aberto (it_open_rule) e edição de multa e juros (it_late_edit).",
      "errors": [
        "VERSION_MISMATCH",
        "SETTINGS_BRANCH_REQUIRED",
        "SETTINGS_FORBIDDEN",
        "SETTINGS_VALUE_INVALID",
        "SETTINGS_SLOT_INVALID",
        "SETTINGS_PARALLEL_INVALID",
        "SETTINGS_RECORD_INVALID",
        "SETTINGS_HOURS_INVALID",
        "SETTINGS_DEBT_INVALID",
        "SETTINGS_METHODS_INVALID",
        "SETTINGS_LATE_INVALID",
        "SETTINGS_DRE_INVALID",
        "SETTINGS_RECEIPT_INVALID",
        "SETTINGS_BUDGET_INVALID"
      ]
    },
    {
      "name": "data_export",
      "signature": "ad.data_export(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Exportação de planilhas da filial (Configurações > Exportar): pacientes, financeiro (contas a receber e a pagar por vencimento, até 400 dias), procedimentos (com custo e preços calculados) ou agenda (por data no fuso da filial). Devolve colunas e linhas (até 20000) para o app montar o Excel. Exige alterar na tela SETTINGS e ler na tela dos dados. Grava event_log só com tipo, período e quantidade de linhas.",
      "errors": [
        "VERSION_MISMATCH",
        "EXPORT_BRANCH_REQUIRED",
        "EXPORT_FORBIDDEN",
        "EXPORT_KIND_INVALID",
        "EXPORT_PERIOD_INVALID"
      ]
    },
    {
      "name": "trash_list",
      "signature": "ad.trash_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Lixeira da filial (Configurações > Lixeira): pacientes inativados, notas excluídas, consultas/compromissos cancelados, contas canceladas, procedimentos e materiais inativados, mais recentes primeiro, com quem excluiu. Exige ler na tela SETTINGS; cada tipo só aparece para quem lê a tela dele; id_restore diz se pode restaurar. Filtro por tipo e busca. Inclui profissionais inativados (AGENDA).",
      "errors": [
        "VERSION_MISMATCH",
        "TRASH_BRANCH_REQUIRED",
        "TRASH_FORBIDDEN",
        "TRASH_KIND_INVALID"
      ]
    },
    {
      "name": "trash_restore",
      "signature": "ad.trash_restore(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Restaura um item da lixeira pela RPC da própria tela (patient_save, patient_note_save R, appointment_save, fin_entry_settle REOPEN, procedure_save, material_save), que confere a permissão de alterar, as regras e grava o log. Exige ler na tela SETTINGS. Profissional pela professional_save.",
      "errors": [
        "VERSION_MISMATCH",
        "TRASH_BRANCH_REQUIRED",
        "TRASH_FORBIDDEN",
        "TRASH_KIND_INVALID",
        "TRASH_NOT_FOUND"
      ]
    },
    {
      "name": "fn_pricing_calc",
      "signature": "od.fn_pricing_calc(p_json jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Fórmula do preço: custo direto = materiais + laboratório + tempo × estrutura/h + tempo × hora clínica; preço = custo ÷ (1 − cartão − comissão − taxas − IR − lucro) no regime PJ (IR sobre o faturamento) ou (1 − IR) × custo ÷ ((1 − IR)(1 − cartão − comissão − taxas) − lucro) no regime PF (IR sobre o lucro); preço mínimo com lucro zero. Devolve a decomposição e id_valid. Com vl_current_price (valor cobrado hoje) devolve também o lucro que sobra com ele e it_price_status: 0 sem valor, 1 ok, 2 abaixo do sugerido, 3 abaixo do mínimo, 4 abaixo do custo direto."
    },
    {
      "name": "fn_pricing_context",
      "signature": "od.fn_pricing_context(p_nr_company bigint, p_nr_branch bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Parâmetros da filial (ou padrões) e resumo: custo mensal das despesas (eventuais ÷ 12), horas por mês, horas produtivas, custo da estrutura por hora (calculado e o efetivo, que pode ser o valor manual), soma das taxas ativas e IR do regime."
    },
    {
      "name": "fn_screen_permission",
      "signature": "ad.fn_screen_permission(p_nr_company bigint, p_nr_branch bigint, p_vc_screen text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Permissão efetiva do usuário logado numa tela e filial ({id_read, id_create, id_update}): filial acessível + nível 100 ou união das linhas de access_profile_screen dos perfis do usuário. Usada pelas RPCs de negócio (schema od)."
    },
    {
      "name": "patient_list",
      "signature": "ad.patient_list(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Lista paginada de pacientes da filial, por nome, com idade: busca por nome/apelido/e-mail (ILIKE, aceita % como curinga) e, com dígitos, por CPF (início), celular/telefone (trecho) e número do prontuário. Filtros: vc_search, id_include_inactive, nr_page, qt_page_size (máx. 200). Devolve a permissão do usuário na tela PATIENTS. Exige leitura na tela PATIENTS.",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_BRANCH_REQUIRED",
        "PATIENT_FORBIDDEN"
      ]
    },
    {
      "name": "patient_get",
      "signature": "ad.patient_get(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Ficha completa de um paciente (todas as colunas, mais qt_age) e as notas gerais ativas, da mais recente para a mais antiga, com o nome do autor. Exige leitura na tela PATIENTS.",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_BRANCH_REQUIRED",
        "PATIENT_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND"
      ]
    },
    {
      "name": "patient_save",
      "signature": "ad.patient_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) a ficha do paciente. Normaliza antes de validar (trim e corte dos textos; CPF, telefones e CEP só dígitos; e-mail minúsculo; UF maiúscula; id_no_email limpa o e-mail). Nascimento obrigatório entre 1900 e hoje; CPFs válidos; CPF do paciente único na filial; e-mail, telefones, CEP, UF e listas it_* validados. Grava event_log sem dados pessoais (nome, situação e campos alterados). Segue as configurações da filial: número de prontuário automático e CPF/celular obrigatórios. Nome, nascimento e CPF são sempre obrigatórios; os campos marcados na filial (branch_setting.vc_patient_required) também (PATIENT_FIELD_REQUIRED com o nome do campo). Na alteração, só valem quando o campo vem no JSON e fica vazio.",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_ACTION_INVALID",
        "PATIENT_BRANCH_REQUIRED",
        "PATIENT_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "PATIENT_VALUE_INVALID",
        "PATIENT_NAME_REQUIRED",
        "PATIENT_BIRTH_REQUIRED",
        "PATIENT_BIRTH_INVALID",
        "PATIENT_CPF_INVALID",
        "PATIENT_CPF_IN_USE",
        "PATIENT_EMAIL_INVALID",
        "PATIENT_PHONE_INVALID",
        "PATIENT_ZIP_INVALID",
        "PATIENT_STATE_INVALID",
        "PATIENT_STATUS_INVALID",
        "PATIENT_CPF_REQUIRED",
        "PATIENT_FIELD_REQUIRED"
      ]
    },
    {
      "name": "patient_note_save",
      "signature": "ad.patient_note_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Notas gerais do paciente: I adiciona (permissão criar ou alterar; autor = usuário da sessão), D exclui logicamente (permissão alterar). Grava event_log. vc_action R restaura uma nota excluída (lixeira, permissão alterar).",
      "errors": [
        "VERSION_MISMATCH",
        "PATIENT_NOTE_ACTION_INVALID",
        "PATIENT_BRANCH_REQUIRED",
        "PATIENT_NOTE_FORBIDDEN",
        "PATIENT_REQUIRED",
        "PATIENT_NOT_FOUND",
        "PATIENT_NOTE_REQUIRED",
        "PATIENT_NOTE_NOT_FOUND"
      ]
    }
  ],
  "mermaid": "erDiagram\n  screen ||--o{ access_profile_screen : \"liberada para perfis\"\n  access_profile ||--o{ access_profile_screen : \"telas do perfil\"\n  app_user ||--o{ event_log : \"atividades\"\n  screen ||--o{ event_log : \"eventos na tela\"\n  company ||--o{ branch : \"possui filiais\"\n  company ||--o{ access_profile : \"define perfis\"\n  company ||--o{ company_user : \"tem usuários\"\n  app_user ||--o{ company_user : \"participa de empresas\"\n  auth_users ||--|| app_user : \"uu_auth\"\n  branch ||--o{ branch_user_profile : \"acesso por filial\"\n  company_user ||--o{ branch_user_profile : \"perfis nas filiais\"\n  access_profile ||--o{ branch_user_profile : \"perfil atribuído\"\n  app_user ||--o{ access_log : \"acessos\"\n  branch ||--o| pricing_param : \"parâmetros de preço\"\n  branch ||--o{ clinic_expense : \"despesas\"\n  branch ||--o{ pricing_fee : \"taxas adicionais\"\n  branch ||--o{ material : \"materiais\"\n  branch ||--o{ specialty : \"especialidades\"\n  specialty |o--o{ procedure : \"agrupa procedimentos\"\n  branch ||--o{ procedure : \"procedimentos\"\n  procedure ||--o{ procedure_material : \"usa materiais\"\n  material ||--o{ procedure_material : \"usado em\"\n  branch ||--o{ patient : \"pacientes\"\n  branch ||--o{ professional : \"profissionais\"\n  professional ||--o{ professional_schedule : \"horário de atendimento\"\n  app_user |o--o{ professional : \"é o profissional\"\n  branch ||--o{ fin_account : \"contas\"\n  branch ||--o{ fin_category : \"plano de contas\"\n  branch ||--o{ fin_supplier : \"fornecedores\"\n  fin_category ||--o{ fin_entry : \"classifica\"\n  fin_account |o--o{ fin_entry : \"movimenta\"\n  fin_supplier |o--o{ fin_entry : \"cobra\"\n  fin_account ||--o{ fin_cash_session : \"caixa do dia\"\n  fin_cash_session |o--o{ fin_entry : \"recebe no caixa\"\n  fin_account ||--o{ fin_card_rate : \"recebe da taxa\"\n  fin_entry ||--o{ fin_receivable : \"gera recebíveis\"\n  fin_card_rate |o--o{ fin_receivable : \"aplica\"\n  fin_transfer |o--o| fin_receivable : \"confirma\"\n  branch ||--o{ health_plan : \"convênios\"\n  health_plan ||--o{ health_plan_price : \"tabela de preço\"\n  procedure ||--o{ health_plan_price : \"preço no convênio\"\n  health_plan ||--o{ health_guide : \"guias\"\n  patient ||--o{ health_guide : \"atendido por convênio\"\n  health_guide ||--|{ health_guide_item : \"procedimentos\"\n  fin_entry |o--o{ health_guide : \"faturamento\"\n  fin_account ||--o{ fin_bank_line : \"extrato do banco\"\n  fin_entry |o--o| fin_bank_line : \"concilia\"\n  fin_category ||--o{ fin_recurrence : \"classifica\"\n  fin_recurrence |o--o{ fin_entry : \"gera\"\n  fin_entry ||--o{ fin_attachment : \"anexa\"\n  patient ||--o{ budget : \"orçamentos\"\n  budget ||--|{ budget_item : \"itens\"\n  anamnesis_model ||--|{ anamnesis_question : \"perguntas\"\n  patient ||--o{ patient_anamnesis : \"anamneses\"\n  anamnesis_model ||--o{ patient_anamnesis : \"preenchida\"\n  patient_anamnesis ||--|{ patient_anamnesis_answer : \"respostas\"\n  patient ||--o{ clinical_evolution : \"evoluções\"\n  budget_item ||--o| clinical_evolution : \"realizado\"\n  professional ||--o{ clinical_evolution : \"atendeu\"\n  patient ||--o{ tooth_mark : \"odontograma\"\n  patient ||--o{ patient_document : \"documentos\"\n  document_template ||--o{ patient_document : \"emitido\"\n  patient_document ||--o{ patient_document_item : \"medicamentos\"\n  medication ||--o{ patient_document_item : \"receitado\"\n  procedure ||--o{ budget_item : \"orçado\"\n  budget ||--o{ fin_entry : \"gera contas\"\n  fin_entry ||--o{ fin_receipt : \"recibos\"\n  fin_account ||--o{ fin_transfer : \"transfere\"\n  fin_cash_session |o--o{ fin_transfer : \"sangria / suprimento\"\n  appointment |o--o{ fin_entry : \"fecha o atendimento\"\n  professional |o--o{ fin_entry : \"comissão\"\n  patient |o--o{ fin_entry : \"paga\"\n  branch ||--o{ appointment : \"agenda\"\n  patient |o--o{ appointment : \"consultas\"\n  professional |o--o{ appointment : \"atende\"\n  procedure |o--o{ appointment : \"previsto em\"\n  patient ||--o{ patient_note : \"notas\"\n  app_user ||--o{ patient_note : \"autor\"\n  auth_users {\n    uuid id PK\n    text email\n  }\n  company {\n    bigint nr_company PK\n    varchar vc_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n    smallint it_mfa_policy\n  }\n  branch {\n    bigint nr_company PK, FK\n    bigint nr_branch PK\n    varchar vc_name\n    varchar vc_legal_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    smallint it_tax_regime\n    varchar vc_state_registration\n    varchar vc_city_registration\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    varchar vc_timezone\n    varchar vc_phone_extra\n    varchar vc_technical_name\n    varchar vc_technical_cro\n    varchar vc_technical_cro_state\n    varchar vc_forum_city\n    boolean id_main\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n  }\n  app_user {\n    bigint nr_user PK\n    uuid uu_auth FK, UK\n    varchar vc_name\n    varchar vc_email UK\n    varchar vc_cpf UK\n    varchar vc_phone\n    varchar vc_mobile\n    text vc_avatar_url\n    smallint it_level\n    smallint it_status\n    varchar vc_block_reason\n    timestamptz dh_last_login\n  }\n  access_profile {\n    bigint nr_company PK, FK\n    bigint nr_profile PK\n    varchar vc_name UK\n    smallint it_level\n    smallint it_status\n  }\n  company_user {\n    bigint nr_company PK, FK\n    bigint nr_user PK, FK\n    bigint nr_company_user UK\n    smallint it_status\n    varchar vc_block_reason\n  }\n  branch_user_profile {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_user PK, FK\n    bigint nr_profile PK, FK\n  }\n  access_log {\n    bigint nr_access PK\n    bigint nr_user FK\n    bigint nr_company\n    bigint nr_branch\n    smallint it_app\n    varchar vc_ip\n    varchar vc_device\n    varchar vc_user_agent\n    varchar vc_app_version\n    timestamptz dh_access\n  }\n  screen {\n    uuid uu_screen PK\n    varchar vc_code\n    varchar vc_name\n    varchar vc_group\n    smallint nr_order\n    smallint it_status\n  }\n  access_profile_screen {\n    bigint nr_company PK, FK\n    bigint nr_profile PK, FK\n    uuid uu_screen PK, FK\n    boolean id_read\n    boolean id_create\n    boolean id_update\n  }\n  event_log {\n    bigint nr_event PK\n    bigint nr_company\n    bigint nr_branch\n    bigint nr_user FK\n    uuid uu_screen FK\n    varchar vc_action\n    varchar vc_entity\n    varchar vc_key\n    varchar vc_summary\n    jsonb js_detail\n    timestamptz dh_event\n  }\n  pricing_param {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    smallint qt_rooms\n    numeric qt_hours_week\n    numeric qt_weeks_month\n    numeric pc_occupancy\n    numeric vl_professional_hour\n    numeric pc_card\n    numeric pc_commission\n    smallint it_tax_regime\n    numeric pc_tax_pf\n    numeric pc_tax_pj\n    numeric pc_profit\n    numeric vl_structure_hour_manual\n  }\n  clinic_expense {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_expense PK\n    varchar vc_name\n    smallint it_type\n    numeric vl_amount\n    smallint it_status\n  }\n  pricing_fee {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_fee PK\n    varchar vc_name\n    varchar vc_hint\n    numeric pc_rate\n    boolean id_active\n  }\n  material {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_material PK\n    varchar vc_name UK\n    varchar vc_package\n    numeric vl_package_price\n    numeric qt_yield\n    varchar vc_unit\n    numeric pc_waste\n    smallint it_price_source\n    varchar vc_price_source\n    timestamptz dh_price_updated\n    smallint it_status\n  }\n  specialty {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_specialty PK\n    varchar vc_name UK\n    numeric pc_profit\n    smallint it_status\n  }\n  procedure_template {\n    bigint nr_template PK\n    varchar vc_specialty UK\n    varchar vc_code\n    varchar vc_name UK\n    numeric qt_minutes\n    numeric vl_material_other\n    numeric vl_lab_cost\n    numeric vl_reference_price\n    integer nr_order\n    smallint it_status\n  }\n  procedure {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_procedure PK\n    varchar vc_code UK\n    varchar vc_name UK\n    bigint nr_specialty FK\n    numeric qt_minutes\n    numeric vl_lab_cost\n    numeric vl_material_other\n    numeric vl_current_price\n    numeric pc_commission\n    numeric pc_profit\n    smallint it_status\n  }\n  procedure_material {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_procedure PK, FK\n    bigint nr_material PK, FK\n    numeric qt_used\n  }\n  professional {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_professional PK\n    varchar vc_name UK\n    varchar vc_council\n    varchar vc_color\n    smallint qt_slot_minutes\n    bigint nr_user FK, UK\n    smallint it_status\n  }\n  professional_schedule {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_professional PK, FK\n    bigint nr_schedule PK\n    smallint it_weekday\n    smallint qt_minute_start\n    smallint qt_minute_end\n  }\n  appointment {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_appointment PK\n    smallint it_type\n    bigint nr_patient FK\n    bigint nr_professional FK\n    bigint nr_procedure FK\n    varchar vc_title\n    text vc_notes\n    timestamptz dh_start\n    timestamptz dh_end\n    boolean id_all_day\n    boolean id_fit_in\n    smallint it_status\n    bigint nr_user_created FK\n  }\n  fin_account {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_account PK\n    varchar vc_name UK\n    smallint it_type\n    numeric vl_opening\n    varchar vc_bank_code\n    varchar vc_bank_name\n    varchar vc_agency\n    varchar vc_account_number\n    smallint it_status\n  }\n  fin_category {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_category PK\n    varchar vc_name UK\n    smallint it_kind\n    smallint it_cost_type\n    smallint it_dre_group\n    smallint it_status\n  }\n  fin_supplier {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_supplier PK\n    varchar vc_name UK\n    varchar vc_document\n    varchar vc_phone\n    varchar vc_email\n    varchar vc_notes\n    smallint it_status\n  }\n  fin_entry {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_entry PK\n    smallint it_kind\n    bigint nr_category FK\n    bigint nr_account FK\n    bigint nr_supplier FK\n    bigint nr_patient FK\n    varchar vc_description\n    numeric vl_amount\n    date dt_due\n    date dt_competence\n    smallint it_payment_method\n    date dt_paid\n    numeric vl_paid\n    smallint it_status\n    uuid uu_group\n    smallint nr_installment\n    smallint qt_installments\n    boolean id_recurring\n    bigint nr_recurrence FK\n    timestamptz dh_health_exported\n    varchar vc_notes\n    bigint nr_user_created FK\n    bigint nr_appointment FK\n    bigint nr_budget FK\n    bigint nr_professional FK\n    bigint nr_cash_session FK\n  }\n  budget {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_budget PK\n    bigint nr_patient FK\n    bigint nr_professional FK\n    varchar vc_title\n    date dt_budget\n    date dt_valid\n    numeric vl_gross\n    numeric vl_discount\n    numeric vl_total\n    smallint qt_installments\n    smallint it_payment_method\n    varchar vc_notes\n    smallint it_status\n    boolean id_discount_approved\n    boolean id_below_min\n    bigint nr_user_discount FK\n    timestamptz dh_discount\n    timestamptz dh_accepted\n    bigint nr_user_created FK\n  }\n  budget_item {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_budget PK, FK\n    smallint nr_item PK\n    bigint nr_procedure FK\n    varchar vc_description\n    varchar vc_tooth\n    numeric qt_quantity\n    numeric vl_unit\n    numeric vl_total\n    date dt_done\n    bigint nr_evolution\n  }\n  anamnesis_model {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_model PK\n    varchar vc_name\n    bigint nr_specialty FK\n    smallint it_status\n  }\n  anamnesis_question {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_model PK, FK\n    smallint nr_question PK\n    varchar vc_question\n    smallint it_type\n    boolean id_alert\n  }\n  patient_anamnesis {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_anamnesis PK\n    bigint nr_model FK\n    varchar vc_model\n    date dt_filled\n    varchar vc_notes\n    smallint it_status\n    bigint nr_user FK\n  }\n  patient_anamnesis_answer {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_anamnesis PK, FK\n    smallint nr_question PK\n    varchar vc_question\n    smallint it_type\n    boolean id_yes\n    varchar vc_text\n    boolean id_alert\n  }\n  clinical_evolution {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_evolution PK\n    timestamptz dh_evolution\n    bigint nr_professional FK\n    varchar vc_text\n    varchar vc_tooth\n    bigint nr_procedure FK\n    bigint nr_budget FK\n    smallint nr_item FK\n    smallint it_status\n    bigint nr_user FK\n  }\n  tooth_mark {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_mark PK\n    varchar vc_tooth\n    smallint it_condition\n    varchar vc_faces\n    smallint it_situation\n    varchar vc_notes\n    date dt_mark\n    smallint it_status\n    bigint nr_user FK\n  }\n  document_template {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_template PK\n    smallint it_kind\n    varchar vc_name\n    varchar vc_body\n    smallint it_status\n  }\n  medication {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_medication PK\n    varchar vc_name\n    varchar vc_presentation\n    varchar vc_dosage\n    varchar vc_quantity\n    smallint it_use\n    boolean id_controlled\n    smallint it_status\n  }\n  patient_document {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_document PK\n    smallint it_kind\n    bigint nr_template FK\n    varchar vc_title\n    varchar vc_body\n    date dt_document\n    bigint nr_professional FK\n    smallint it_status\n    bigint nr_user FK\n  }\n  patient_document_item {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_document PK, FK\n    smallint nr_item PK\n    bigint nr_medication FK\n    varchar vc_name\n    varchar vc_presentation\n    varchar vc_dosage\n    varchar vc_quantity\n    smallint it_use\n    boolean id_controlled\n  }\n  fin_cash_session {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_session PK\n    bigint nr_account FK\n    bigint nr_user FK\n    timestamptz dh_open\n    numeric vl_open\n    timestamptz dh_close\n    numeric vl_counted\n    numeric vl_expected\n    smallint it_status\n    varchar vc_notes\n    bigint nr_user_closed FK\n  }\n  fin_transfer {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_transfer PK\n    smallint it_type\n    bigint nr_account_from FK\n    bigint nr_account_to FK\n    numeric vl_amount\n    date dt_transfer\n    varchar vc_description\n    bigint nr_cash_session FK\n    smallint it_status\n    bigint nr_user_created FK\n  }\n  fin_card_rate {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_rate PK\n    varchar vc_name\n    smallint it_payment_method\n    smallint qt_installments_min\n    smallint qt_installments_max\n    numeric pc_fee\n    numeric vl_fee_fixed\n    smallint qt_days\n    bigint nr_account FK\n    smallint it_status\n  }\n  fin_receivable {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_receivable PK\n    bigint nr_entry FK\n    bigint nr_rate FK\n    smallint it_payment_method\n    smallint nr_installment\n    smallint qt_installments\n    numeric vl_gross\n    numeric vl_fee\n    numeric vl_net\n    date dt_expected\n    bigint nr_account FK\n    smallint it_status\n    date dt_received\n    numeric vl_received\n    bigint nr_transfer FK\n    bigint nr_fee_entry FK\n    varchar vc_reference\n    varchar vc_card_brand\n    varchar vc_card_last4\n    varchar vc_authorization\n    varchar vc_holder_name\n    varchar vc_holder_document\n    varchar vc_bank_name\n    varchar vc_check_number\n    bigint nr_user_created FK\n  }\n  health_plan {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_plan PK\n    varchar vc_name\n    varchar vc_ans\n    varchar vc_document\n    smallint qt_payment_days\n    bigint nr_account FK\n    varchar vc_notes\n    smallint it_status\n  }\n  health_plan_price {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_plan PK, FK\n    bigint nr_procedure PK, FK\n    varchar vc_code\n    numeric vl_price\n  }\n  health_guide {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_guide PK\n    bigint nr_plan FK\n    bigint nr_patient FK\n    bigint nr_professional FK\n    bigint nr_appointment FK\n    varchar vc_guide_number\n    varchar vc_card_number\n    date dt_service\n    numeric vl_total\n    smallint it_status\n    bigint nr_entry FK\n    date dt_invoiced\n    date dt_paid\n    numeric vl_paid\n    numeric vl_denied\n    varchar vc_notes\n    bigint nr_user_created FK\n  }\n  health_guide_item {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_guide PK, FK\n    smallint nr_item PK\n    bigint nr_procedure FK\n    varchar vc_tooth\n    smallint qt_quantity\n    numeric vl_unit\n    numeric vl_total\n    numeric vl_denied\n  }\n  fin_bank_line {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_line PK\n    bigint nr_account FK\n    varchar vc_fitid\n    date dt_posted\n    numeric vl_amount\n    varchar vc_memo\n    smallint it_status\n    bigint nr_entry FK\n    bigint nr_transfer FK\n    bigint nr_user_created FK\n  }\n  fin_recurrence {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_recurrence PK\n    smallint it_kind\n    bigint nr_category FK\n    bigint nr_account FK\n    bigint nr_supplier FK\n    bigint nr_patient FK\n    varchar vc_description\n    numeric vl_amount\n    smallint it_day\n    smallint it_payment_method\n    date dt_start\n    date dt_end\n    date dt_generated\n    smallint it_status\n    varchar vc_notes\n    bigint nr_user_created FK\n  }\n  fin_attachment {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_attachment PK\n    bigint nr_entry FK\n    smallint it_type\n    varchar vc_path\n    varchar vc_name\n    varchar vc_mime\n    bigint qt_bytes\n    smallint it_status\n    bigint nr_user_created FK\n  }\n  fin_receipt {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_receipt PK\n    varchar vc_number\n    bigint nr_entry FK\n    numeric vl_amount\n    date dt_paid\n    smallint it_payment_method\n    varchar vc_payer_name\n    varchar vc_payer_document\n    varchar vc_description\n    smallint it_status\n    varchar vc_cancel_reason\n    bigint nr_user_created FK\n  }\n  branch_setting {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    smallint qt_slot_minutes\n    smallint qt_max_parallel\n    boolean id_allow_outside_hours\n    boolean id_auto_record_number\n    bigint nr_next_record\n    text[] vc_patient_required\n    smallint it_debt_rule\n    smallint qt_debt_days\n    boolean id_cash_enabled\n    smallint[] it_payment_methods\n    numeric pc_late_fee\n    numeric pc_late_interest\n    varchar vc_receipt_prefix\n    bigint nr_next_receipt\n    numeric pc_budget_max_discount\n    smallint qt_budget_valid_days\n    boolean id_budget_request_approval\n    boolean id_budget_admin_below_min\n    boolean id_budget_reduction_as_discount\n    smallint it_open_rule\n    smallint it_late_edit\n    numeric pc_dre_revenue_tax\n    numeric pc_dre_income_tax\n    numeric pc_dre_csll\n  }\n  branch_hour {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_hour PK\n    smallint it_weekday\n    smallint qt_minute_start\n    smallint qt_minute_end\n  }\n  patient {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK\n    varchar vc_name\n    varchar vc_nickname\n    varchar vc_cpf UK\n    varchar vc_rg\n    date dt_birth\n    smallint it_gender\n    smallint it_marital_status\n    smallint it_education\n    smallint it_source\n    varchar vc_referral\n    text vc_notes\n    varchar vc_phone\n    varchar vc_mobile\n    varchar vc_phone_other\n    varchar vc_contact_name\n    varchar vc_email\n    boolean id_no_email\n    varchar vc_zip\n    varchar vc_state\n    varchar vc_city\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_district\n    varchar vc_address_complement\n    varchar vc_record_number\n    varchar vc_profession\n    varchar vc_workplace\n    varchar vc_work_time\n    varchar vc_plan_name\n    varchar vc_plan_number\n    varchar vc_father_name\n    varchar vc_father_cpf\n    varchar vc_father_rg\n    varchar vc_father_profession\n    varchar vc_mother_name\n    varchar vc_mother_cpf\n    varchar vc_mother_rg\n    varchar vc_mother_profession\n    varchar vc_guardian_name\n    varchar vc_guardian_cpf\n    varchar vc_guardian_rg\n    varchar vc_guardian_phone\n    date dt_return_alert\n    varchar vc_return_alert\n    smallint it_status\n  }\n  patient_note {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_note PK\n    text vc_note\n    bigint nr_user FK\n    timestamptz dh_note\n    smallint it_status\n  }"
};
