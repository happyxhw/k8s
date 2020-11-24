helm install redis bitnami/redis\
    --set global.storageClass=nfs-storage\
    --set metrics.enabled=true\
    --set sentinels.enabled=true\
    --set global.redis.password=808258