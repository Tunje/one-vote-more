# Rebuild type table: the starting-price calculator (Bob, 2026-11-17). Run: python rebuild_type_table_calc.py
# Prints every starting price, then the month-one check (planning/rebuild-type-table.md sections 1 and 9).
import math, json
HH_PERS=2.5; HH_EARN=1.25; TIER=dict(G=1.0,S=1.5,Sp=2.25)
PAYBACK_Y=13.5; LAND_SHARE=0.10
# Otto's bills: BW, MAT, COMP, months (one full unit)
B={"FARM":(240,240,12,4),"BAKERY":(300,240,24,4),"MINE":(600,480,72,6),"PROCESSING":(720,600,96,8),
"COMPONENTS":(720,600,120,8),"CONSUMERF":(480,480,60,6),"MEDWORKS":(480,360,96,6),"TEXTILE":(420,360,48,5),
"FURNITURE":(420,360,48,5),"POWER":(840,840,180,8),"WATERWORKS":(540,540,72,6),"HAULIER":(300,240,48,4),
"TRUCKSHOP":(240,180,24,3),"SERVICEHUB":(240,240,12,3),"CHILDCARE":(240,240,12,3),"ELDERCARE":(240,240,12,3),
"SHOP":(240,240,12,3),"CAFE":(240,240,12,3),"CLINIC":(480,420,36,6),"SCHOOL":(480,480,18,6),"POLICE":(360,360,24,4),
"ADMIN":(360,360,12,4),"PRISON":(600,720,36,6),"BANK":(240,240,12,3),"NEWSPAPER":(180,180,12,3),
"OFFICEBLOCK":(300,300,15,4),"LANDLORD":(1200,720,24,6),"BUILDER":(120,120,6,2),"TRANSIT":(300,240,48,4),
"SANITATION":(240,240,12,3)}
# rows: type -> list of lines (out item or clients kind, qty, inputs, labour)
R={
"FARM":[("FOOD",156,{},dict(G=18,S=5,Sp=1))],
"BAKERY":[("BREAD",1500,{"FOOD":1300,"ENERGY":3000,"WATER":1500},dict(G=12,S=5,Sp=1)),
          ("FINE_FOOD",400,{"FOOD":700,"ENERGY":3000,"WATER":1000},dict(G=10,S=6,Sp=2))],
"MINE":[("MINERAL",2000,{"ENERGY":8000,"WATER":2000},dict(G=20,S=8,Sp=2))],
"PROCESSING":[("MATERIAL",800,{"MINERAL":1600,"ENERGY":12000,"WATER":4000},dict(G=18,S=10,Sp=2))],
"COMPONENTS":[("COMPONENT",200,{"MATERIAL":250,"ENERGY":8000},dict(G=10,S=14,Sp=6)),
              ("TRUCK",4,{"MATERIAL":60,"COMPONENT":40,"ENERGY":6000},dict(G=10,S=14,Sp=6))],
"CONSUMERF":[("CONSUMER",1200,{"MATERIAL":150,"COMPONENT":20,"ENERGY":6000},dict(G=16,S=10,Sp=2))],
"TEXTILE":[("CLOTHING",1000,{"FOOD":100,"MATERIAL":40,"ENERGY":4000,"WATER":2000},dict(G=18,S=6,Sp=1))],
"FURNITURE":[("FURNISHINGS",300,{"MATERIAL":200,"COMPONENT":5,"ENERGY":3000},dict(G=14,S=8,Sp=1))],
"MEDWORKS":[("MEDICAL",600,{"MATERIAL":30,"COMPONENT":10,"ENERGY":5000,"WATER":3000},dict(G=6,S=10,Sp=6))],
"POWER":[("ENERGY",120000,{"MINERAL":1200,"WATER":5000},dict(G=8,S=8,Sp=4))],
"WATERWORKS":[("WATER",120000,{"ENERGY":15000,"MATERIAL":10},dict(G=6,S=5,Sp=2))],
"BUILDER":[("BW",60,{},dict(G=36,S=18,Sp=6))],
"HAULIER":[("FREIGHT_UKM",36000,{"ENERGY":12000},dict(G=2,S=6,Sp=0))],    # 6 trucks x 6000 unit-km
"TRUCKSHOP":[("@truck repair",12,{"COMPONENT":6,"ENERGY":2000},dict(G=2,S=5,Sp=1)),
             ("TRUCK",1,{"MATERIAL":15,"COMPONENT":10,"ENERGY":2000},dict(G=2,S=5,Sp=1))],
"SERVICEHUB":[("@household",300,{"ENERGY":2000,"WATER":1000},dict(G=6,S=4,Sp=0))],
"SHOP":[("@household",400,{"ENERGY":3000},dict(G=8,S=2,Sp=0))],
"CAFE":[("@visit",1500,{"FOOD":150,"FINE_FOOD":60,"ENERGY":3000,"WATER":2000},dict(G=8,S=2,Sp=0))],
"CHILDCARE":[("@child",120,{"FOOD":60,"ENERGY":2000,"WATER":1000},dict(G=4,S=10,Sp=1))],
"ELDERCARE":[("@resident",80,{"FOOD":80,"MEDICAL":20,"ENERGY":3000,"WATER":2000},dict(G=8,S=10,Sp=2))],
"CLINIC":[("@person",2000,{"MEDICAL":80,"ENERGY":4000,"WATER":2000},dict(G=4,S=10,Sp=6))],
"SCHOOL":[("@pupil",300,{"MATERIAL":5,"ENERGY":3000,"WATER":1000},dict(G=2,S=12,Sp=4))],
"POLICE":[("@resident",2500,{"ENERGY":2000},dict(G=4,S=10,Sp=1))],
"PRISON":[("@prisoner",50,{"FOOD":50,"ENERGY":3000,"WATER":2000},dict(G=4,S=10,Sp=1))],
"ADMIN":[("@resident",3000,{"ENERGY":2000},dict(G=4,S=8,Sp=3))],
"TRANSIT":[("@rider",1000,{"ENERGY":20000},dict(G=2,S=10,Sp=0))],
"SANITATION":[("@home",1500,{"ENERGY":4000,"WATER":6000},dict(G=10,S=2,Sp=0))],
"NEWSPAPER":[("@reader",2000,{"MATERIAL":4,"ENERGY":2000},dict(G=3,S=6,Sp=3))],
"BANK":[("@loan",60,{"ENERGY":1000},dict(G=2,S=6,Sp=4))],
"OFFICEBLOCK":[("@office place",10,{"ENERGY":4000,"WATER":1000},dict(G=2,S=0,Sp=0))],
"LANDLORD":[("@home",50,{},dict(G=2,S=0,Sp=0))],
}
P={"FOOD":20,"BREAD":25,"FINE_FOOD":60,"MINERAL":8,"MATERIAL":40,"COMPONENT":150,"TRUCK":6000,"CONSUMER":20,
   "CLOTHING":15,"FURNISHINGS":70,"MEDICAL":30,"ENERGY":0.2,"WATER":0.1,"BW":300,"FREIGHT_UKM":0.1}
SVC={}
W={"G":300}
def wage(t): return W["G"]*TIER[t]
def billcost(t, share=1.0):
    bw,m,c,_=B[t]; return share*(bw*P["BW"]+m*P["MATERIAL"]+c*P["COMPONENT"])
def upkeep(t):
    bw,m,c,_=B[t]; return m/400*P["MATERIAL"] + 0.02*bw/12*P["BW"]
def cost(t,line):
    item,q,inp,lab=line
    L=sum(wage(k)*n for k,n in lab.items()); I=sum(P[i]*x for i,x in inp.items())
    return L,I,upkeep(t)
rent_home=0
for it in range(200):
    seen=set()
    for t,lines in R.items():
        for ln in lines:
            item,q,_,_=ln
            L,I,U=cost(t,ln)
            if t=="LANDLORD":
                home_build=billcost(t)/50*(1+LAND_SHARE)
                rent_home = home_build/(PAYBACK_Y*12) + (L+I+U)/50
                SVC["LANDLORD"]=rent_home; continue
            N = 13.5 if t=="OFFICEBLOCK" else 10.0
            mk=(L+I+U)/q + billcost(t)*(1+LAND_SHARE)/(N*12)/q
            if item.startswith("@"): SVC[t if len(lines)==1 or item!="TRUCK" else t]=mk
            else:
                P[item]=min(P[item],mk) if item in seen else mk; seen.add(item)  # an item two rows make starts at the cheaper
    pass
shelter=W["G"]/1.2-HH_PERS*P["FOOD"]
out=dict(P=P,SVC=SVC,W={k:wage(k) for k in TIER},rent_home=rent_home,shelter=shelter)
print(json.dumps(out,indent=1))
rows=[]
for t,lines in R.items():
    bc=billcost(t)
    for ln in lines:
        item,q,inp,lab=ln; L,I,U=cost(t,ln)
        price = SVC.get(t) if item.startswith("@") else P[item]
        if t=="LANDLORD": rev=50*rent_home
        else: rev=q*price
        prof=rev-(L+I+U); 
        rows.append((t,item,q,round(price,3),round((L+I+U)/q,3),round(L),round(I),round(U),round(bc),round(bc/max(prof,1)/12,1),sum(lab.values())))
for r in rows: print(r)
G=W["G"]

# ---- month-one check
share=1/6
SAV={"I1":6*G,"I2":12*G,"I3":24*G,"I4":48*G,"I5":120*G}
GRANT={"FARM":15000,"BAKERY":15000,"HAULIER":10000,"TRUCKSHOP":10000}
HOME_MULT=2.0
print("type | bill (BW/MAT/COMP, months) | build cr | land | 3 months opening | total | total w/o opening | grant | poorest band that reaches it (with opening / without)")
for t in B:
    if t in ("LANDLORD","OFFICEBLOCK","BUILDER"): pass
    bw,m,c,mo=B[t]; months=max(2, math.ceil(mo*(1+share)/2))
    build=share*(bw*P["BW"]+m*P["MATERIAL"]+c*P["COMPONENT"])
    land=0.1*build
    run=0
    for ln in R.get(t,[])[:1]:
        _,q,inp,lab=ln
        run=share*(sum(wage(k)*n for k,n in lab.items())+sum(P[i]*x for i,x in inp.items())+ (m/400*P["MATERIAL"]+0.02*bw/12*P["BW"]))
    if t=="HAULIER":
        build=P["TRUCK"]*HOME_MULT; land=0; months=0
    open3=3*run; tot=build+land+open3; tot2=build+land
    g=GRANT.get(t,0)
    def band(x):
        for b,s in SAV.items():
            if s+g>=x: return b
        return "none"
    print(f"{t} | {bw*share:.0f}/{m*share:.0f}/{c*share:.1f}, {months} | {build:,.0f} | {land:,.0f} | {open3:,.0f} | {tot:,.0f} | {tot2:,.0f} | {g:,} | {band(tot)} / {band(tot2)}")
print(SAV)
# family farm economics
q=R["FARM"][0][1]/6*0.94; rev=q*P["FOOD"]; _,_,inp,lab=R["FARM"][0]
cost=(sum(wage(k)*n for k,n in lab.items())+240/400*P["MATERIAL"]+0.02*240/12*P["BW"])/6
print("family farm: food/month",q,"revenue",round(rev),"costs",round(cost))
# landing stock
bwm=180*60; mat=sum(b[1] for b in B.values())/sum(b[0] for b in B.values()); comp=sum(b[2] for b in B.values())/sum(b[0] for b in B.values())
print("MAT/BW",round(mat,2),"COMP/BW",round(comp,3),"landing MAT",round(bwm*mat),"COMP",round(bwm*comp), "value", round(bwm*mat*P["MATERIAL"]+bwm*comp*P["COMPONENT"]))

# ---- can the chain feed itself? (outside review, 2026-11-17): A[j][i] = units of item j used to make one unit of item i
# (the first row that makes i). The goods economy can produce a surplus of every item only if A's spectral radius < 1.
ITEMS_IO=["FOOD","BREAD","FINE_FOOD","MINERAL","MATERIAL","COMPONENT","TRUCK","CONSUMER","CLOTHING","FURNISHINGS","MEDICAL","ENERGY","WATER"]
maker={}
for t,lines in R.items():
    for (o,q,inp,lab) in lines:
        if o in ITEMS_IO and o not in maker: maker[o]=(q,inp)
ix={k:i for i,k in enumerate(ITEMS_IO)}; n=len(ITEMS_IO); A=[[0.0]*n for _ in range(n)]
for o,(q,inp) in maker.items():
    for j,x in inp.items(): A[ix[j]][ix[o]]=x/q
v=[1.0]*n; rho=0.0
for _ in range(2000):
    w=[sum(A[i][j]*v[j] for j in range(n)) for i in range(n)]
    rho=max(w); v=[x/rho for x in w]
print("spectral radius of the input-output matrix:", round(rho,4), "(must be below 1)")
