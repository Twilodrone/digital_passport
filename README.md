# Описание

## База данных включает 5 основных таблиц, отражающих доменную модель:

1. objects
2. object_metadata
3. passports
4. passport_versions
5. passport_locks


**1. objects — сущность объекта**\
Хранит информацию о реальном объекте инфраструктуры
(например, светофорный объект или контроллер).


| Поле   | Тип    | Описание  |
| ------ | ------ | ------ |
| id  | bigserial PK   | глобальный уникальный идентификатор объекта |
| name  | text unique	   | внутренний идентификатор   |
| created_at | timestamptz   | Дата создания   |
|updated_at |	timestamptz |дата обновления
	    	            
	        	
Все остальные таблицы привязаны к объекту по object_id


**2. object_metadata — метаданные объекта**\
Таблица хранит информацию, которую система получает из внешнего источника
и обновляет фоновым процессом.

Эти данные не редактируются пользователем.

|Поле | Тип	| Описание |
| ------ | ------ | ------ |
|object_id | bigint PK FK |	ссылка на объект
address	   |         text |	        адрес объекта
longitude  |        numeric(9,6) |	долгота
latitude   |	    numeric(9,6) |	широта
region	   |         text	     |   регион(Округ МСК) 
source_updated_at |	timestamptz	 |   когда источник обновил данные
synced_at	|        timestamptz	 |   когда мы обновили данные у себя
created_at	|        timestamptz	 |   дата создания
updated_at	|        timestamptz	 |   дата обновления

*Особенности*\
Обновляется бекендом при синхронизации
Не зависит от версий паспорта
Не входит в историю изменений


**3. passports — актуальный паспорт объекта**\
Содержит данные текущего паспорта, включая большой JSON-payload. (data)

|Поле | Тип	| Описание |
| ------ | ------ | ------ |
id	       | bigserial        |   PK	
object_id  |bigint unique FK  |	ссылка на объект (один объект → один паспорт)
data	   |jsonb	          |  большой JSON объёмом до 1–2 МБ
note	   | text	          |  пользовательское примечание
version	   | integer	      |      текущая версия паспорта
created_by |	text	      |      кто создал
updated_by |	text	      |      кто обновил
created_at |	timestamptz	  |
updated_at |	timestamptz	  |

*Особенности*\
data хранит как структурированные поля, так и Base64 изображения
PostgreSQL хранит большие JSON через TOAST → эффективно и надёжно
При сохранении новой версии текущая копируется в passport_versions


**4. passport_versions — история изменений паспорта**
Каждая запись — полная копия паспорта в момент изменения.

|Поле | Тип	| Описание |
| ------ | ------ | ------ |
id	       | bigserial |  PK	
object_id  | bigint FK |	ссылка на объект
version	   | integer   |	    номер версии
data	   | jsonb	   | snapshot паспорта
note	   | text	   | заметки на тот момент
created_by | text	   | автор изменения
created_at | timestamptz |	дата фиксации

*Особенности*\
Позволяет восстанавливать прошлые состояния паспорта
Структура идентична passports, но только для чтения


**5. passport_locks — блокировка редактирования (TTL)**
Лок во время редактирования.
|Поле | Тип	| Описание |
| ------ | ------ | ------ |
passport_id	   | bigint PK FK |	ссылка на паспорт
locked_by	   | text	      |  кто редактирует
locked_at	   | timestamptz  |	    время начала редактирования
expires_at	   | timestamptz  |	    время истечения блокировки
session_id	   | text	      |  идентификатор сессии
created_at	   | timestamptz  |	

*Особенности*\
Один паспорт -> одна активная блокировка
Блокировка снимается автоматически, если TTL прошёл.


## Запуск через Docker

**1. Докер:**

docker compose up -d

**2. Применение миграций:**

Применить SQL-файл с миграциями:\
```psql -U passport_user -d passport_db -f db/init.sql```

Проверить таблицы:\
```psql -U passport_user -d passport_db -c "\dt"```


**Примеры взаимодействия:**

*Добавить объект*
```
INSERT INTO objects(name)
VALUES ('413');
```

*Добавить метаданные*
```
INSERT INTO object_metadata(object_id, address, region)
VALUES (1, 'Main St 5', 'Center');
```

*Создать паспорт*
```
INSERT INTO passports(object_id, data, note, created_by)
VALUES (1, '{}'::jsonb, 'Initial version', 'admin');
```
*Скопировать текущий паспорт в историю:*
```
INSERT INTO passport_versions(object_id, version, data, note, created_by)
SELECT object_id, version, data, note, updated_by
FROM passports
WHERE object_id = 1;
```
*Обновить паспорт:*
```
UPDATE passports
SET version = version + 1,
    data = '{"new":"value"}',
    note = 'Updated',
    updated_by = 'admin',
    updated_at = now()
WHERE object_id = 1;
```
*Поставить блокировку с TTL (10 минут)*
```
INSERT INTO passport_locks (passport_id, locked_by, expires_at)
VALUES (1, 'admin', now() + interval '10 minutes')
ON CONFLICT (passport_id)
DO UPDATE SET
    locked_by = EXCLUDED.locked_by,
    locked_at = now(),
    expires_at = EXCLUDED.expires_at;
```
*Снять блокировку*\
```DELETE FROM passport_locks WHERE passport_id = 1;```