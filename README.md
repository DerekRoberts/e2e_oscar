# OSCAR-E2E Exporter

## Consume SQL and Export E2E

Consume any OSCAR SQL dumps in $SQL_PATH, including compressed .XZ files, and exports E2E.

-e DEL_DUMPS=no can be added to prevent deletion of SQL.


```bash
sudo docker pull hdcbc/e2e_oscar:latest
sudo docker run -ti --rm --name e2o -h e2o (optional: -e DEL_DUMPS=no) --link gateway --volume ${SQL_PATH}:/import:rw e2o
```
