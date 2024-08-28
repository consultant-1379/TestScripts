#!/bin/bash
SL2_SIM=$(ls /netsim/netsim_dbdir/simdir/netsim/netsimdir/ | egrep 'LTE|RNC|MGw' | grep -v DG2)
TLS_SIM=$(ls /netsim/netsim_dbdir/simdir/netsim/netsimdir/ | egrep 'DG2|TCU|SpitFire')
for SIM in $SL2_SIM
do
echo '.open' $SIM
echo '.select network'
echo '.stop'
echo '.setssliop createormodify sl2'
echo '.setssliop import /netsim/NODE_DUSGen2OAM_ENTITY.p12 secured secured'
echo '.setssliop serverpassword secured'
echo '.setssliop serververify 0'
echo '.setssliop serverdepth 1'
echo '.setssliop clientpassword secured'
echo '.setssliop clientverify 0'
echo '.setssliop clientdepth 1'
echo '.setssliop protocol_version sslv2|sslv3'
echo '.setssliop save force'
echo '.set ssliop no->yes sl2'
echo '.set save'
echo '.start'
done

for SIM in $TLS_SIM
do
echo '.open' $SIM
echo '.select network'
echo '.stop'
echo '.setssliop createormodify tls'
echo '.setssliop import /netsim/NODE_DUSGen2OAM_ENTITY.p12 secured secured'
echo '.setssliop serverpassword secured'
echo '.setssliop serververify 0'
echo '.setssliop serverdepth 0'
echo '.setssliop clientpassword secured'
echo '.setssliop clientverify 0'
echo '.setssliop clientdepth 0'
echo '.setssliop save force'
echo '.set ssliop no tls'
echo '.set save'
echo '.start'
done
