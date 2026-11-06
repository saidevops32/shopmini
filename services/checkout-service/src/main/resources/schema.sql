create table if not exists orders (
  id bigserial primary key,
  user_id varchar(64) not null,
  total numeric(12,2) not null,
  created_at timestamptz not null default now()
);
create table if not exists order_lines (
  order_id bigint not null references orders(id),
  product_id bigint not null,
  name varchar(120) not null,
  unit_price numeric(10,2) not null,
  quantity int not null
);
create table if not exists outbox (
  id bigserial primary key,
  payload text not null,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists idx_outbox_unsent on outbox (id) where sent_at is null;
