#Minimization
shopt -s nullglob
em_log=(./*em.log)
if ((${#em_log[@]})); then
echo "Minimization finished"
else
gmx grompp -f em.mdp -c system.gro -r system.gro -p topol.top -n index.ndx -o em.tpr
gmx mdrun -ntomp 20 -ntmpi 1 -v -nb gpu -deffnm em
fi

#Temperature
shopt -s nullglob
nvt_log=(./*nvt.log)
if ((${#nvt_log[@]})); then
echo "NVT finished"
else
gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -n index.ndx -o nvt.tpr
gmx mdrun -ntomp 20 -ntmpi 1 -v -nb gpu -deffnm nvt
fi

#Pression
shopt -s nullglob
npt_log=(./*npt.log)
if ((${#npt_log[@]})); then
echo "NPT finished"
else
gmx grompp -f npt.mdp -c nvt.gro -t nvt.cpt -r nvt.gro -p topol.top -n index.ndx -o npt.tpr
gmx mdrun -ntomp 20 -ntmpi 1 -v -nb gpu -deffnm npt
fi

#Production

md_steps=$(awk -v var=nsteps '{if( $1 == var) {print $3}}' md.mdp)
dt=$(awk -v var=dt '{if( $1 == var) {print $3}}' md.mdp)
#echo "Integration time in ps is: $((dt))"
time_ns=$(echo "scale=3; $md_steps*$dt/1000" | bc)
#echo "Number of steps is: $md_steps"
echo "Time in ns is : $(echo "scale=0; $time_ns " | bc)"

start_md=1
save_each=1			# change this value to save each "n"
n_iterations=$(echo "scale=0; $time_ns/$save_each" | bc)
echo "Number of iterations is: $n_iterations"

sed -i "4s/.*/nsteps                  = $(echo "scale=0; $save_each*1000/$dt " | bc)    ; $save_each ns/" md.mdp #check nsteps is line 4, if not change the value

while [ $start_md -le $n_iterations ]; do
	prev_i=$((start_md-1))
	if (($start_md == 1 )); then 
	gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -n index.ndx -o md_$start_md.tpr
	gmx mdrun -ntomp 20 -ntmpi 1 -v -nb gpu -deffnm md_$start_md
	else
	gmx convert-tpr -s md_$prev_i.tpr -extend $(echo "scale=0; $save_each*1000 " | bc) -o md_$start_md.tpr
	gmx mdrun -ntomp 20 -ntmpi 1 -v -nb gpu -deffnm md_$start_md -cpi md_$prev_i.cpt -noappend
	fi
	start_md=$((start_md+1));
done
