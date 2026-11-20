begin;
lock table gtl_payroll_private.master in share mode;
lock table gtl_payroll_private.published_labour in share row exclusive mode;
do $check$
begin
  if not exists(select 1 from gtl_payroll_private.master where id) then
    raise exception 'No saved payroll master';
  end if;
  if not exists (
    select 1 from gtl_payroll_private.published_labour p
    cross join lateral jsonb_array_elements(p.totals) j(item)
    where p.id and j.item->>'customer'='DSV' and j.item->>'job'='4974'
      and jsonb_array_length(coalesce(j.item->'operationCosts','[]'::jsonb))>0
  ) then
    raise exception 'No saved vehicle costs for DSV job 4974';
  end if;
end;
$check$;
with operation_inputs as (
  select * from jsonb_to_recordset($gtl$[{"customer":"DSV","job":"4974","id":"L-113320","day":0,"ot":150,"heads":7,"crew":[{"epf":"4481","role":"Supervisor"},{"epf":"400177","role":"Tally Clerk"},{"epf":"6300","role":"Operator"},{"epf":"6393","role":"Operator"},{"epf":"6430","role":"Operator"},{"epf":"6567","role":"Operator"},{"epf":"6823","role":"Operator"}]},{"customer":"DSV","job":"4974","id":"L-113415","day":200,"ot":0,"heads":9,"crew":[{"epf":"4481","role":"Supervisor"},{"epf":"400177","role":"Tally Clerk"},{"epf":"4459","role":"Tally Clerk"},{"epf":"4484","role":"Tally Clerk"},{"epf":"6300","role":"Operator"},{"epf":"6391","role":"Operator"},{"epf":"6544","role":"Operator"},{"epf":"6567","role":"Operator"},{"epf":"6836","role":"Operator"}]},{"customer":"DSV","job":"4974","id":"L-113540","day":140,"ot":0,"heads":7,"crew":[{"epf":"4361","role":"Supervisor"},{"epf":"400177","role":"Tally Clerk"},{"epf":"4459","role":"Tally Clerk"},{"epf":"6300","role":"Operator"},{"epf":"6393","role":"Operator"},{"epf":"6430","role":"Operator"},{"epf":"6823","role":"Operator"}]}]$gtl$::jsonb)
    as op(customer text,job text,id text,day numeric,ot numeric,heads integer,crew jsonb)
), crew_costs as (
  select op.customer,op.job,op.id,op.heads,op.day,op.ot,c.role,
    op.day/60*(rate->>'regularPay')::numeric/m.hours as day_cost,
    op.ot/60*(rate->>'basic')::numeric/200*1.5 as ot_cost
  from operation_inputs op
  cross join gtl_payroll_private.master m
  cross join lateral jsonb_to_recordset(op.crew) as c(epf text,role text)
  cross join lateral (select m.records->c.epf as rate) as pay
  where m.id and rate is not null
), role_costs as (
  select customer,job,id,heads,role,count(*) as matched,
    sum(day) as day_minutes,sum(ot) as ot_minutes,sum(day_cost) as day_cost,sum(ot_cost) as ot_cost
  from crew_costs group by customer,job,id,heads,role
), priced as (
  select customer,job,id,heads,sum(matched) as matched,round(sum(day_cost+ot_cost),2) as amount,
    jsonb_agg(jsonb_build_object('role',role,'dayMinutes',day_minutes,'otMinutes',ot_minutes,
      'dayCost',round(day_cost,2),'otCost',round(ot_cost,2),'totalCost',round(day_cost+ot_cost,2))) as roles
  from role_costs group by customer,job,id,heads
), patched as (
  select j.item, coalesce((
    select jsonb_agg(operations.op) from (
      select v.op from jsonb_array_elements(j.item->'operationCosts') v(op)
      where not exists (select 1 from operation_inputs i where i.id=v.op->>'id')
      union all
      select jsonb_build_object('id',p.id,'amount',p.amount,'complete',p.matched=p.heads,'roles',p.roles)
      from priced p
    ) operations
  ),'[]'::jsonb) as costs
  from gtl_payroll_private.published_labour l
  cross join lateral jsonb_array_elements(l.totals) j(item)
  where l.id and j.item->>'customer'='DSV' and j.item->>'job'='4974'
), job_totals as (
  select item||jsonb_build_object('operationCosts',costs,
    'amount', coalesce((select sum((v.op->>'amount')::numeric) from jsonb_array_elements(costs) v(op)),0),
    'pricedVisits',jsonb_array_length(costs),
    'roles',coalesce((
      select jsonb_agg(jsonb_build_object('direction',r.direction,'role',r.role,
        'dayMinutes',r.day_minutes,'otMinutes',r.ot_minutes,
        'dayCost',r.day_cost,'otCost',r.ot_cost,'totalCost',r.total_cost))
      from (
        select left(v.op->>'id',1) as direction, e.role,
          sum(e."dayMinutes") as day_minutes,sum(e."otMinutes") as ot_minutes,
          sum(e."dayCost") as day_cost,sum(e."otCost") as ot_cost,sum(e."totalCost") as total_cost
        from jsonb_array_elements(costs) v(op)
        cross join lateral jsonb_to_recordset(coalesce(v.op->'roles','[]'::jsonb))
          e(role text,"dayMinutes" numeric,"otMinutes" numeric,"dayCost" numeric,"otCost" numeric,"totalCost" numeric)
        group by 1,2
      ) r
    ),'[]'::jsonb)) as updated_job
  from patched
)
update gtl_payroll_private.published_labour l
set totals=(
  select jsonb_agg(case when j.item->>'customer'='DSV' and j.item->>'job'='4974'
    then t.updated_job else j.item end)
  from jsonb_array_elements(l.totals) j(item) cross join job_totals t
), updated=now()
where l.id and exists(select 1 from job_totals);
commit;

select v.op->>'id' as operation_id, v.op->>'amount' as labour_cost
from jsonb_array_elements(public.gtl_public_labour_totals()) j(item)
cross join lateral jsonb_array_elements(j.item->'operationCosts') v(op)
where j.item->>'customer'='DSV' and j.item->>'job'='4974'
 and v.op->>'id' in ('L-113320','L-113415','L-113540')
order by 1;
