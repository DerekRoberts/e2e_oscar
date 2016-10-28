# OSCAR-E2E Exporter

## Consume SQL and Export E2E

This will consume any OSCAR SQL dumps in $SQL_PATH.  $DEL_DUMPS will either rename or delete consumed SQL.

```bash
sudo docker pull hdcbc/e2e_oscar:latest
sudo docker run -ti --rm --name e2o -h e2o -e DEL_DUMPS=${DEL_DUMSP} --link gateway --volume ${SQL_PATH}:/import:rw e2o
```
