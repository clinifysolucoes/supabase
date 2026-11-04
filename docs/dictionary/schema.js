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
  "updated": "2026-10-14",
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
      "name": "procedure",
      "title": "Procedimento",
      "description": "Procedimento precificado: tempo de cadeira, laboratório/terceiros, outros materiais (valor informado), valor cobrado hoje (só comparação) e, opcionalmente, comissão e lucro próprios. O preço não é gravado: procedure_list calcula sempre com os parâmetros atuais (od.fn_pricing_calc).",
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
          "name": "vc_category",
          "type": "varchar(40)",
          "nullable": true,
          "description": "Categoria / especialidade (Clínica Geral, Ortodontia, Implante, HOF...)."
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
          "description": "Lucro desejado próprio (% sobre o preço). Nulo = usa pricing_param.pc_profit."
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
      "description": "Login do app após o Supabase Auth: devolve usuário, empresas → filiais → perfis acessíveis (com it_level e id_admin) e vínculos bloqueados com motivo; grava access_log e dh_last_login. Cada filial traz permissions: telas que o usuário pode ler/criar/alterar (nível 100 tem todas; DASHBOARD sempre).",
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
      "description": "Atualização parcial dos dados cadastrais da empresa. Somente administrador. Situação/bloqueio só por service_role.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_UPDATE_COMPANY_REQUIRED",
        "COMPANY_UPDATE_FORBIDDEN",
        "COMPANY_UPDATE_NAME_REQUIRED",
        "COMPANY_UPDATE_CNPJ_INVALID",
        "COMPANY_UPDATE_CNPJ_IN_USE",
        "COMPANY_UPDATE_EMAIL_INVALID"
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
      "description": "Atualização parcial da filial, inclusive transferência de matriz (id_main). Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_UPDATE_KEY_REQUIRED",
        "BRANCH_UPDATE_FORBIDDEN",
        "BRANCH_UPDATE_NOT_FOUND",
        "BRANCH_UPDATE_NAME_REQUIRED",
        "BRANCH_UPDATE_CNPJ_INVALID",
        "BRANCH_UPDATE_CNPJ_IN_USE",
        "BRANCH_UPDATE_EMAIL_INVALID",
        "BRANCH_UPDATE_TIMEZONE_INVALID"
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
      "description": "Pares (nr_company, nr_branch) acessíveis agora: vínculo com perfil ativo, usuário ativo na empresa, empresa e filial ativas e não bloqueadas."
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
      "description": "Procedimentos da filial com materiais, preço calculado (fn_pricing_calc), preço mínimo, decomposição (cartão, comissão, taxas, IR, lucro) e alertas (NO_TIME, NO_MATERIAL, MATERIAL_NO_PRICE, PERCENT_TOO_HIGH). it_tax_regime simula PF x PJ. Devolve também parâmetros, resumo e categorias. Exige leitura na tela PRICING.",
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
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) um procedimento e, quando materials está presente, substitui seus materiais x quantidades. Grava event_log.",
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
        "PROCEDURE_REQUIRED",
        "PROCEDURE_NOT_FOUND"
      ]
    },
    {
      "name": "fn_pricing_calc",
      "signature": "od.fn_pricing_calc(p_json jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Fórmula do preço: custo direto = materiais + laboratório + tempo × estrutura/h + tempo × hora clínica; preço = custo ÷ (1 − cartão − comissão − taxas − IR − lucro) no regime PJ (IR sobre o faturamento) ou (1 − IR) × custo ÷ ((1 − IR)(1 − cartão − comissão − taxas) − lucro) no regime PF (IR sobre o lucro); preço mínimo com lucro zero. Devolve a decomposição e id_valid."
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
      "description": "Cria (I, permissão criar) ou atualiza parcialmente (U, permissão alterar) a ficha do paciente. Normaliza antes de validar (trim e corte dos textos; CPF, telefones e CEP só dígitos; e-mail minúsculo; UF maiúscula; id_no_email limpa o e-mail). Nascimento obrigatório entre 1900 e hoje; CPFs válidos; CPF do paciente único na filial; e-mail, telefones, CEP, UF e listas it_* validados. Grava event_log sem dados pessoais (nome, situação e campos alterados).",
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
        "PATIENT_STATUS_INVALID"
      ]
    },
    {
      "name": "patient_note_save",
      "signature": "ad.patient_note_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Notas gerais do paciente: I adiciona (permissão criar ou alterar; autor = usuário da sessão), D exclui logicamente (permissão alterar). Grava event_log.",
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
  "mermaid": "erDiagram\n  screen ||--o{ access_profile_screen : \"liberada para perfis\"\n  access_profile ||--o{ access_profile_screen : \"telas do perfil\"\n  app_user ||--o{ event_log : \"atividades\"\n  screen ||--o{ event_log : \"eventos na tela\"\n  company ||--o{ branch : \"possui filiais\"\n  company ||--o{ access_profile : \"define perfis\"\n  company ||--o{ company_user : \"tem usuários\"\n  app_user ||--o{ company_user : \"participa de empresas\"\n  auth_users ||--|| app_user : \"uu_auth\"\n  branch ||--o{ branch_user_profile : \"acesso por filial\"\n  company_user ||--o{ branch_user_profile : \"perfis nas filiais\"\n  access_profile ||--o{ branch_user_profile : \"perfil atribuído\"\n  app_user ||--o{ access_log : \"acessos\"\n  branch ||--o| pricing_param : \"parâmetros de preço\"\n  branch ||--o{ clinic_expense : \"despesas\"\n  branch ||--o{ pricing_fee : \"taxas adicionais\"\n  branch ||--o{ material : \"materiais\"\n  branch ||--o{ procedure : \"procedimentos\"\n  procedure ||--o{ procedure_material : \"usa materiais\"\n  material ||--o{ procedure_material : \"usado em\"\n  branch ||--o{ patient : \"pacientes\"\n  patient ||--o{ patient_note : \"notas\"\n  app_user ||--o{ patient_note : \"autor\"\n  auth_users {\n    uuid id PK\n    text email\n  }\n  company {\n    bigint nr_company PK\n    varchar vc_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n  }\n  branch {\n    bigint nr_company PK, FK\n    bigint nr_branch PK\n    varchar vc_name\n    varchar vc_legal_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    smallint it_tax_regime\n    varchar vc_state_registration\n    varchar vc_city_registration\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    varchar vc_timezone\n    boolean id_main\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n  }\n  app_user {\n    bigint nr_user PK\n    uuid uu_auth FK, UK\n    varchar vc_name\n    varchar vc_email UK\n    varchar vc_cpf UK\n    varchar vc_phone\n    varchar vc_mobile\n    text vc_avatar_url\n    smallint it_level\n    smallint it_status\n    varchar vc_block_reason\n    timestamptz dh_last_login\n  }\n  access_profile {\n    bigint nr_company PK, FK\n    bigint nr_profile PK\n    varchar vc_name UK\n    smallint it_level\n    smallint it_status\n  }\n  company_user {\n    bigint nr_company PK, FK\n    bigint nr_user PK, FK\n    bigint nr_company_user UK\n    smallint it_status\n    varchar vc_block_reason\n  }\n  branch_user_profile {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_user PK, FK\n    bigint nr_profile PK, FK\n  }\n  access_log {\n    bigint nr_access PK\n    bigint nr_user FK\n    bigint nr_company\n    bigint nr_branch\n    smallint it_app\n    varchar vc_ip\n    varchar vc_device\n    varchar vc_user_agent\n    varchar vc_app_version\n    timestamptz dh_access\n  }\n  screen {\n    uuid uu_screen PK\n    varchar vc_code\n    varchar vc_name\n    varchar vc_group\n    smallint nr_order\n    smallint it_status\n  }\n  access_profile_screen {\n    bigint nr_company PK, FK\n    bigint nr_profile PK, FK\n    uuid uu_screen PK, FK\n    boolean id_read\n    boolean id_create\n    boolean id_update\n  }\n  event_log {\n    bigint nr_event PK\n    bigint nr_company\n    bigint nr_branch\n    bigint nr_user FK\n    uuid uu_screen FK\n    varchar vc_action\n    varchar vc_entity\n    varchar vc_key\n    varchar vc_summary\n    jsonb js_detail\n    timestamptz dh_event\n  }\n  pricing_param {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    smallint qt_rooms\n    numeric qt_hours_week\n    numeric qt_weeks_month\n    numeric pc_occupancy\n    numeric vl_professional_hour\n    numeric pc_card\n    numeric pc_commission\n    smallint it_tax_regime\n    numeric pc_tax_pf\n    numeric pc_tax_pj\n    numeric pc_profit\n    numeric vl_structure_hour_manual\n  }\n  clinic_expense {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_expense PK\n    varchar vc_name\n    smallint it_type\n    numeric vl_amount\n    smallint it_status\n  }\n  pricing_fee {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_fee PK\n    varchar vc_name\n    varchar vc_hint\n    numeric pc_rate\n    boolean id_active\n  }\n  material {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_material PK\n    varchar vc_name UK\n    varchar vc_package\n    numeric vl_package_price\n    numeric qt_yield\n    varchar vc_unit\n    numeric pc_waste\n    smallint it_price_source\n    varchar vc_price_source\n    timestamptz dh_price_updated\n    smallint it_status\n  }\n  procedure {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_procedure PK\n    varchar vc_code UK\n    varchar vc_name UK\n    varchar vc_category\n    numeric qt_minutes\n    numeric vl_lab_cost\n    numeric vl_material_other\n    numeric vl_current_price\n    numeric pc_commission\n    numeric pc_profit\n    smallint it_status\n  }\n  procedure_material {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_procedure PK, FK\n    bigint nr_material PK, FK\n    numeric qt_used\n  }\n  patient {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK\n    varchar vc_name\n    varchar vc_nickname\n    varchar vc_cpf UK\n    varchar vc_rg\n    date dt_birth\n    smallint it_gender\n    smallint it_marital_status\n    smallint it_education\n    smallint it_source\n    varchar vc_referral\n    text vc_notes\n    varchar vc_phone\n    varchar vc_mobile\n    varchar vc_phone_other\n    varchar vc_contact_name\n    varchar vc_email\n    boolean id_no_email\n    varchar vc_zip\n    varchar vc_state\n    varchar vc_city\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_district\n    varchar vc_address_complement\n    varchar vc_record_number\n    varchar vc_profession\n    varchar vc_workplace\n    varchar vc_work_time\n    varchar vc_plan_name\n    varchar vc_plan_number\n    varchar vc_father_name\n    varchar vc_father_cpf\n    varchar vc_father_rg\n    varchar vc_father_profession\n    varchar vc_mother_name\n    varchar vc_mother_cpf\n    varchar vc_mother_rg\n    varchar vc_mother_profession\n    varchar vc_guardian_name\n    varchar vc_guardian_cpf\n    varchar vc_guardian_rg\n    varchar vc_guardian_phone\n    date dt_return_alert\n    varchar vc_return_alert\n    smallint it_status\n  }\n  patient_note {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_patient PK, FK\n    bigint nr_note PK\n    text vc_note\n    bigint nr_user FK\n    timestamptz dh_note\n    smallint it_status\n  }"
};
