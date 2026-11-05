create table if not exists products (
  id bigint auto_increment primary key,
  name varchar(120) not null,
  description varchar(500),
  price decimal(10,2) not null,
  stock int not null default 0,
  unique key uq_products_name (name)
);
