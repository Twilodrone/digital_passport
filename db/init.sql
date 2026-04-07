-- OBJECTS
create table objects (
    id              bigserial primary key,
    name            text not null unique,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- METADATA
create table object_metadata (
    object_id           bigint primary key references objects(id) on delete cascade,
    address             text,
    longitude           numeric(9,6),
    latitude            numeric(9,6),
    region              text,
    source_updated_at   timestamptz,
    synced_at           timestamptz not null default now(),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- ACTIVE PASSPORT
create table passports (
    id              bigserial primary key,
    object_id       bigint not null references objects(id) on delete cascade unique,
    data            jsonb not null,
    note            text,
    version         integer not null default 1,
    created_by      text,
    updated_by      text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- HISTORY OF PASSPORTS
create table passport_versions (
    id              bigserial primary key,
    object_id       bigint not null references objects(id) on delete cascade,
    version         integer not null,
    data            jsonb not null,
    note            text,
    created_by      text,
    created_at      timestamptz not null default now(),
    unique (object_id, version)
);

-- LOCKS
create table passport_locks (
    passport_id     bigint primary key references passports(id) on delete cascade,
    locked_by       text not null,
    locked_at       timestamptz not null default now(),
    expires_at      timestamptz not null,
    session_id      text,
    created_at      timestamptz not null default now()
);

-- INDEXES
create index idx_metadata_region on object_metadata(region);
create index idx_passport_versions_object on passport_versions(object_id);
create index idx_objects_name on objects(name);
