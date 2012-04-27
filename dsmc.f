*   DSMC1.FOR
*Original by G.A. Bird
*schuberm added law-kelton, maxwell & cll kernels, fixed missing particles bug
*Warning from schuberm: Check that energy is conserved
      PROGRAM DSMC1
*
*--general one-dimensional steady flow program
*----includes options for cylindrical and spherical flows
*----flow gradients occur only in the direction of the x axis
*----the x axis becomes the radius in cylindrical and spherical cases
*------the origin is then at x=0
*----the axis of a cylindrical flow is along the z axis
*----in plane flows, there may be a velocity in the y direction
*----in cylindrical flow, there may be a circumferential velocity
*----the is an `inner' (smaller x) and `outer' (larger x) boundary
*----each boundary is one of five types
*-----1: an axis or centre (it must then be at x=0)
*-----2: a plane of symmetry or a specularly reflecting surface
*-----3: a solid surface
*-----4: a stream boundary
*-----5: a vacuum
*----the cell widths may be either uniform or in geometric progression
*----there may be a constant `gravitational' acceleration in plane flows
*------with type 4 or type 5 boundaries
*
*--SI units are used throughout
*
*-------------------------DESCRIPTION OF DATA---------------------------
* 
*--the following is set in the PARAMETER statement
*--MNC the number of cells
*--(the other PARAMETER variables must be consistent with the data in
*----SUBROUTINE DATA1, and MNSC can set a default if NSC is not set)
*
*--IFC set to 0 or 1 for uniform or non-uniform cell widths
*---if IFC=1, set CWR as the ratio of the cell width at the outer
*----boundary to that at the inner boundary (default 0)
*
*--IFX set to 0, 1, or 2 for plane, cylindrical, or spherical flow
*
*--IIS 0 if the initial state is a vacuum, 1 if it is a uniform stream,
*----or 2 for a uniform gradient between two surfaces
*
*--FTMP the stream temperature if IIS=1, or a temperature characteristic
*----of the flow otherwise (of FTMP is not set for IIS= 0 or 2, the
*----default value of 273 is used to set the initial value of CCG(1
*
*--FND the initial number density for IIS=1, the mean value for IIS=2,
*----or need not be set for IIS=0
*
*--FSP(L) the fraction (by number) of species L in the initial stream
*----a value is requred for each species, but need not be set for IIS=0
*
*--FNUM the number of real mols. represented by each simulated molecule
*
*--DTM the time step over which the motion and collisions are uncoupled
*
*--NSC the number of sub-cells per cell (MNSC must be at least MNC*NSC)
*----this is optional because MNSC/MNC will be set as the default value
*
*--the following data is required for each boundary
*----K=1 for the inner boundary (lower value of x)
*----K=2 for the outer boundary (higher value of x)
*
*--XB(K) the x coordinate of the boundary (must be positive if IFX>1)
*
*--IB(K) the type code of the boundary
*
*--no further data on the boundary is required if:-
*----IB(K)=1 for an axis or centre (valid for IFX= 1 or 2, and XB(K)=0),
*----IB(K)=2 for a plane of symmetry (if IFX=1) or a specularly
*------reflecting surface (valid for all IFX values)
*----IB(K)=5 for an interface with a vacuum
*
*--if IB(K)=3 (a solid surface) the following are required:-
*--BT(K) the temperature of the surface (diffuse reflection)
*--BVY(K) the velocity in the y direction (not valid for IFX=2)
*
*--if IB(K)=4 (an interface with an external stream) the reqd. data is:-
*--BFND(K) the number density of the stream
*--BFTMP(K) the temperature
*--BVFX(K) the x (and only) component of the stream velocity
*--BFSP(K,L) the number fraction of species L in the stream
*----a value of BFSP is required for each species
*
*--end of the boundary data
*
*--ISPD (required only for gas mixtures) set to 0 if the diameter,
*----viscosity exponent, and VSS scattering parameter for the
*----cross-collisions are to be set to the mean values, or
*----set to 1 if these quantities are to be set as data
*
*--the following data must be repeated for each species (L=1 to MNSP)
*
*--SP(1,L) the reference diameter
*--SP(2,L) the reference temperature
*--SP(3,L) the viscosity temperature power law
*--SP(4,L) the reciprocal of the VSS scattering parameter (1. for VHS)
*--SP(5,L) the molecular mass
*
*--ISP(L) the collision sampling group in which the species lies
*----this must be LE.MNSC (not required if MNSG=1)
*
*--ISPR(1,L) the number of rotational degrees of freedom
*--ISPR(2,L) 0, 1 for constant, polynomial rotational relaxation number
*--ISPR(3,L) 0, 1 for common or collision partner species dependent
*----rotational relaxation rate
*
*--SPR(1,L,K) the constant value, or constant in the polynomial for Zr
*----in a collision of species L with species K
*--the following two items are required only if ISPR(2,L)=1
*--SPR(2,L,K) the coefficient of temperature in the polynomial
*--SPR(3,L,K) the coefficient of temperature squared in the polynomial
*
*--end of data for the individual species
*
*--the following data on the cross-collisions is required only if ISPD=1
*--then only for L.NE.M, but L,M data must be repeated for M,L
*
*--SPM(1,L,M) the reference diameter for species L-M collisions
*--SPM(2,L,M) the reference temperature for species L-M collisions
*--SPM(3,L,M) the viscosity temperature power law for species L-M colls.
*--SPM(4,L,M) the reciprocal of the VSS scattering parameter
*
*--end of species data
*
*--GRAV the gravitational acceleration in the x direction (default 0.)
*----this should be non-zero only when IFX=0 (plane flows) and the
*------boundaries are either type 4 or type 5
*
*--NIS the number of DTM time steps between samplings
*
*--NSP the number of samples between prints
*
*--NPS the number of prints to the assumed start of steady flow
*
*--NPT the number of prints to STOP
*
*-----------------------------------------------------------------------
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
*--variables as defined in DSMC0.FOR
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
*
*--variables as defined in DSMC0.FOR
*
      DOUBLE PRECISION CSR(MNC,MNSP)
*
*--CSR(M,L) the sum of the rotational energy of species L in cell M
*
      DOUBLE PRECISION CSH(4,MNC,MNSP)
*
*--(CSH(N,M,L) higher order sampling in cell M of species L
*----N=1 sum of u*v
*----N=2 sum of c**2*u
*----N=3 sum of rotl. energy*u
*
      DOUBLE PRECISION CSS(8,2,MNSP)
*
*--CSS(N,M,L) sampled info. on the molecules striking the boundaries
*----M=1, 2 for the inner, outer boundaries; L is the species
*----N=1 the number sum
*----N=2 the sum of the normal momentum of the incident molecules
*----N=3 the sum of the normal momentum for the reflected molecules
*----N=4 the sum of the incident parallel momentum in the y direction
*----N=5 the sum of the incident translational energy
*----N=6 the sum of the reflected translational energy
*----N=7 the sum of the incident rotational energy
*----N=8 the sum of the reflected rotational energy
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
*
*--variables as defined in DSMC0.FOR
*
      COMMON /MOLSR / PR(MNM)
*
*--PR(M) is the rotational energy of molecule M
*
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
*
*--IFC 0,1 for uniform cell width, cell widths in geometric progression
*--CWR the ratio of cell width at outer boundary to that at inner bound.
*--variables as defined in DSMC0.FOR
*
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
*
*--variables as defined in DSMC0.FOR
*
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
*
*--variables as defined in DSMC0R.FOR
*
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
*
*--variables as defined in DSMC0.FOR
*
      COMMON /SAMPR / CSR
*
      COMMON /SAMPS / CSS
*
      COMMON /SAMPH / CSH
*--double precision variables defined above
*
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
*
*--variables as defined in DSMC0.FOR
*
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
*
*--IFX 0, 1, or 2 for plane, cylindrical, or spherical flow
*--IIS 0, 1, or 2 if the initial flow is a vacuum, uniform stream, or
*----a uniform gradient between the values at two solid surfaces
*--NSC the number of sub-cells per cell
*--XB(N) N=1, 2 the location of the inner, outer boundary
*--IB(N) N=1, 2 the type code for the inner, outer boundary
*--no further data is needed if IB=1, 2, or 5
*--if IB=3 (solid surface), the following info. is needed (N as above)
*--BT(N) the temperature of the surface
*--BVY(N) the y velocity component (valid for IFX= 0 or 1)
*--if IB=4 (external gas stream), the following info. (N as above)
*--BFND(N) the number density of the external stream
*--BFTMP(N) the temperature
*--BVFX(N) the x component of the velocity
*--BFSP(N,L) the fraction of species L in the stream
*--the following are non-data variables that can apply for IB=3, or 4
*--BME(N,L) the number of molecules of species L that enter at each DTM
*--BMR(N,L) the remainder associated with entry number
*--CW the cell width for uniform cells
*--FW the flow width
*--GRAV the gravitational acceleration in the x direction
*
      COMMON /CONST / PI,SPI,BOLTZ
	
      LOGICAL FLAG(MNM)
      REAL INCI(MNM),SCATTER(MNM),TRACK(MNM),STRKPOS(MNM)
      REAL SCATPOS(MNM)
      COMMON FLAG,INCIDENT,SCATTER,TRACK,STRKPOS,SCATPOS

      REAL NU_H(1000000),SPD(1000000)
      COMMON /OUTERBOUN/ HCOND0,QAVE,NU_H,Q_CON,SPD
      COMMON /LAWKEL/ SLOPE(100000)
      REAL A(1000000)

*
*--variables as defined in DSMC0.FOR
*
c      WRITE (*,*) ' INPUT 0,1 FOR CONTINUING,NEW CALCULATION:- '
c      READ (*,*) NQL
c      WRITE (*,*) ' INPUT 0,1 FOR CONTINUING,NEW SAMPLE:- '
c      READ (*,*) NQLS
* 
      OPEN  (4,FILE='./INPUT1.DAT',STATUS='OLD')
      READ  (4,*) NQL
	CLOSE (4)

      OPEN  (4,FILE='./INPUT2.DAT',STATUS='OLD')
      READ  (4,*) NQLS
	CLOSE (4)
*
      IF (NQL.EQ.1) THEN
*
        CALL INIT1
*
      ELSE
*
        WRITE (*,*) ' READ THE RESTART FILE'
        OPEN (4,FILE='unun.RES',STATUS='OLD',FORM='UNFORMATTED')
        READ (4) AP,BFND,BFSP,BFTMP,BME,BMR,BOLTZ,BT,BVFX,BVY,CC,CCG,CG,
     &           COL,CS,CSH,CSR,CSS,CT,CW,CWR,DTM,FNUM,FTMP,FW,GRAV,IB,
     &           IC,IFC,IFX,IIS,IPL,IPS,IR,ISC,ISCG,ISP,ISPR,MOVT,NCOL,
     &           NIS,NM,NPS,NSC,NSMP,NPR,NPT,NSP,PI,PP,PR,PV,RP,SELT,
     &           SEPT,SP,SPI,SPM,SPR,TIME,TIMI,XB
        CLOSE (4)
*
      END IF
*
      IF (NQLS.EQ.1) CALL SAMPI1
*
100   NPR=NPR+1
*
c      IF (NPR.LE.NPS) CALL SAMPI1
*     
      L=NPR
      A(L)=REAL(NPR)/REAL(NPS)
c      OPEN(4,FILE='A.txt',FORM='FORMATTED')
c	DO I=1,NPR
c	   WRITE(4,999) I, A(I)
c	END DO
c 999  FORMAT (' ',I16,1P,E12.4)
*
	IF (ABS(A(L)-1.).LT.1.E-6) CALL SAMPI1
	IF (ABS(A(L)-2.).LT.1.E-6) CALL SAMPI1
	IF (ABS(A(L)-3.).LT.1.E-6) CALL SAMPI1
        IF (MOD(NPR,100).EQ.0.0) CALL LAWKELTON(NPR/100)
*        IF (ABS(A(L)-4.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-5.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-6.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-7.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-8.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-9.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-10.).LT.1.E-6) CALL SAMPI1
*        IF (ABS(A(L)-11.).LT.1.E-6) CALL SAMPI1
*
      DO 200 JJJ=1,NSP
        DO 150 III=1,NIS
          TIME=TIME+DTM
*
          WRITE (*,99001) III,JJJ,NIS,NSP,NM,IDINT(NCOL)
99001     FORMAT (' DSMC1:- Move',2I5,' of',2I5,I8,' Mols',I14,' Colls')
*
          CALL MOVE1
*
          CALL INDEXM
*
          CALL COLLMR
*
150     CONTINUE
*
        CALL SAMPLE1
*
200   CONTINUE
*
      WRITE (*,*) ' WRITING RESTART AND OUTPUT FILES',NPR,'  OF ',NPT
      OPEN (4,FILE='unun.RES',FORM='UNFORMATTED')
      WRITE (4) AP,BFND,BFSP,BFTMP,BME,BMR,BOLTZ,BT,BVFX,BVY,CC,CCG,CG,
     &          COL,CS,CSH,CSR,CSS,CT,CW,CWR,DTM,FNUM,FTMP,FW,GRAV,IB,
     &          IC,IFC,IFX,IIS,IPL,IPS,IR,ISC,ISCG,ISP,ISPR,MOVT,NCOL,
     &          NIS,NM,NPS,NSC,NSMP,NPR,NPT,NSP,PI,PP,PR,PV,RP,SELT,
     &          SEPT,SP,SPI,SPM,SPR,TIME,TIMI,XB
	      CLOSE (4)
*
      N_NU_H=NPR
*     
      CALL OUT1(N_NU_H)
      IF (NPR.LT.NPT) GO TO 100
      STOP
      END
*   INIT1.FOR
*
      SUBROUTINE INIT1
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSR(MNC,MNSP)
 
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPR / CSR
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
      COMMON /CONST / PI,SPI,BOLTZ
*
*--set constants
*
      PI=3.141592654
      SPI=SQRT(PI)
      BOLTZ=1.380622E-23
*
*--set data variables to default values that they retain if the data
*----does not reset them to specific values
      NSC=MNSC/MNC
      FND=0.
      FTMP=273.
      GRAV=0.
      IFC=1
      DO 100 N=1,2
        XB(N)=0.
        IB(N)=5
        BT(N)=0.
        BVY(N)=0.
        BFND(N)=0.
        BFTMP(N)=0.
        BVFX(N)=0.
        DO 50 L=1,MNSP
          ISP(L)=1
          FSP(L)=0.
          BFSP(N,L)=0.
          BME(N,L)=0.
          BMR(N,L)=0.
50      CONTINUE
100   CONTINUE
*
      CALL DATA1
*
*--set additional data on the gas
*
      IF (MNSP.EQ.1) ISPD=0
      DO 200 N=1,MNSP
        DO 150 M=1,MNSP
          IF ((ISPR(3,N).EQ.0).AND.(M.NE.N)) THEN
            SPR(1,N,M)=SPR(1,N,N)
            SPR(2,N,M)=SPR(2,N,N)
            SPR(3,N,M)=SPR(3,N,N)
          END IF
          IF ((ISPD.EQ.0).OR.(N.EQ.M)) THEN
            SPM(1,N,M)=0.25*PI*(SP(1,N)+SP(1,M))**2
*--the collision cross section is assumed to be given by eqn (1.35)
            SPM(2,N,M)=0.5*(SP(2,N)+SP(2,M))
            SPM(3,N,M)=0.5*(SP(3,N)+SP(3,M))
            SPM(4,N,M)=0.5*(SP(4,N)+SP(4,M))
*--mean values are used for ISPD=0
          ELSE
            SPM(1,N,M)=PI*SPM(1,N,M)**2
*--the cross-collision diameter is converted to the cross-section
          END IF
          SPM(5,N,M)=(SP(5,N)/(SP(5,N)+SP(5,M)))*SP(5,M)
*--the reduced mass is defined in eqn (2.7)
          SPM(6,N,M)=GAM(2.5-SPM(3,N,M))
150     CONTINUE
200   CONTINUE
*
*--initialise variables
*
      TIME=0.
      NM=0
      NPR=0
      NCOL=0
      MOVT=0.
      SELT=0.
      SEPT=0.
      CWR=100
*
      DO 300 M=1,MNSP
        DO 250 N=1,MNSP
          COL(M,N)=0.
250     CONTINUE
300   CONTINUE
*
      FW=XB(2)-XB(1)
      CG(1,1)=XB(1)
      IF (IFC.EQ.0) THEN
        CW=FW/MNC
*--CW is the uniform cell width
      ELSE
        RP=CWR**(1./(MNC-1.))
*--RP is the ratio in the geometric progression
        AP=(1.-RP)/(1.-RP**MNC)
*--AP is the first term of the progression
      END IF
      DO 400 M=1,MNC
        CT(M)=FTMP
*--the macroscopic temperature is set to the freestream temperature
        IF (M.GT.1) CG(1,M)=CG(2,M-1)
        IF (IFC.EQ.0) THEN
          CG(2,M)=CG(1,M)+CW
        ELSE
          CG(2,M)=CG(1,M)+FW*AP*RP**(M-1)
        END IF
        CG(3,M)=CG(2,M)-CG(1,M)
        IF (IFX.EQ.0) CC(M)=CG(3,M)
*--a plane flow has unit cross-sectional area
        IF (IFX.EQ.1) CC(M)=PI*(CG(2,M)**2-CG(1,M)**2)
*--a cylindrical flow has unit length in the axial direction
        IF (IFX.EQ.2) CC(M)=(4./3.)*PI*(CG(2,M)**3-CG(1,M)**3)
*--a spherical flow occupies the full sphere
        DO 350 L=1,MNSG
          DO 320 K=1,MNSG
            CCG(2,M,L,K)=RF(0)
            CCG(1,M,L,K)=SPM(1,1,1)*300.*SQRT(FTMP/300.)
320       CONTINUE
350     CONTINUE
*--the maximum value of the (rel. speed)*(cross-section) is set to a
*--reasonable, but low, initial value and will be increased as necessary
400   CONTINUE
      IF (IFC.EQ.1) THEN
        AP=(1.-RP)/AP
        RP=LOG(RP)
*--AP and RP are now the convenient terms in eqn (12.1)
      END IF
*
*--set sub-cells
*
      DO 500 N=1,MNC
        DO 450 M=1,NSC
          L=(N-1)*NSC+M
          ISC(L)=N
450     CONTINUE
500   CONTINUE
*
      IF (IIS.GT.0) THEN
*--if IIS=1 generate initial gas with temperature FTMP, or
*--if IIS=2 generate initial gas as a uniform gradient between two
*----surfaces (valid only if IB(1)=3 and IB(2)=3)
*
        IF (IIS.EQ.2.AND.(IB(1).NE.3.OR.IB(2).NE.3)) THEN
          WRITE (*,*) ' IIS=2 IS AN ILLEGAL OPTION IN THIS CASE '
          STOP
        END IF
        DO 550 L=1,MNSP
          REM=0
          IF (IIS.EQ.1) VMP=SQRT(2.*BOLTZ*FTMP/SP(5,L))
*--VMP is the most probable speed in species L, see eqns (4.1) and (4.7)
          DO 520 N=1,MNC
            IF (IIS.EQ.2) THEN
              PROP=(N-0.5)/FLOAT(MNC)
              VELS=BVY(1)+PROP*(BVY(2)-BVY(1))
              TMPS=BT(1)+PROP*(BT(2)-BT(1))
              FNDS=FND*0.5*(BT(1)+BT(2))/TMPS
              VMP=SQRT(2.*BOLTZ*TMPS/SP(5,L))
            ELSE
              FNDS=FND
              TMPS=FTMP
            END IF
            A=FNDS*CC(N)*FSP(L)/FNUM+REM
*--A is the number of simulated molecules of species L in cell N to
*--simulate the required concentrations at a total number density of FND
            IF (N.LT.MNC) THEN
              MM=A
              REM=(A-MM)
*--the remainder REM is carried forward to the next cell
            ELSE
              MM=NINT(A)
            END IF
            IF (MM.GT.0) THEN
              DO 505 M=1,MM
                IF (NM.LT.MNM) THEN
*--round-off error could have taken NM to MNM+1
                  NM=NM+1
                  IPS(NM)=L
                  IF (IFX.EQ.0) PP(NM)=CG(1,N)+RF(0)*(CG(2,N)-CG(1,N))
                  IF (IFX.EQ.1) PP(NM)=SQRT(CG(1,N)**2+RF(0)*(CG(2,N)**2
     &                                 -CG(1,N)**2))
                  IF (IFX.EQ.2) PP(NM)=(CG(1,N)**3+RF(0)*(CG(2,N)**3-CG(
     &                                 1,N)**3))**0.3333333
                  IPL(NM)=(PP(NM)-CG(1,N))*(NSC-.001)/CG(3,N)
     &                    +1+NSC*(N-1)
*--species, position, and sub-cell number have been set
                  DO 502 K=1,3
                    CALL RVELC(PV(K,NM),A,VMP)
502               CONTINUE
                  IF (IIS.EQ.2) PV(2,NM)=PV(2,NM)+VELS
*--velocity components have been set
*--set the rotational energy
                  IF (ISPR(1,L).GT.0) CALL SROT(PR(NM),TMPS,ISPR(1,L))
                END IF
505           CONTINUE
            END IF
520       CONTINUE
550     CONTINUE
      END IF
*
      WRITE (*,99001) NM
99001 FORMAT (' ',I6,' MOLECULES')
*
*--calculate the number of molecules that enter at each time step
      DO 600 N=1,2
        IF (IB(N).EQ.4) THEN
*--the entry molecules are from an external stream
          DO 560 L=1,MNSP
            VMP=SQRT(2.*BOLTZ*BFTMP(N)/SP(5,L))
*--VMP is the most probable speed in species L, see eqns (4.1) and (4.7)
            IF (N.EQ.1) SC=BVFX(N)/VMP
            IF (N.EQ.2) SC=-BVFX(N)/VMP
*--SC is the inward directed speed ratio
            IF (ABS(SC).LT.10.1) A=(EXP(-SC*SC)+SPI*SC*(1.+ERF(SC)))
     &                             /(2.*SPI)
            IF (SC.GT.10.) A=SC
            IF (SC.LT.-10.) A=0.
*--A is the non-dimensional flux of eqn (4.22)
            IF (IFX.EQ.1) A=A*2.*PI*XB(N)
            IF (IFX.EQ.2) A=A*4.*PI*XB(N)**2
            BME(N,L)=BFND(N)*BFSP(N,L)*A*VMP*DTM/FNUM
            WRITE (*,*) ' entering mols ',BME(N,L)
560       CONTINUE
        END IF
600   CONTINUE
      RETURN
      END
*   MOVE1.FOR
 
*
      SUBROUTINE MOVE1
*
*--the NM molecules are moved over the time interval DTM
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSS(8,2,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPS / CSS
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
      COMMON /CARTE/ XPOS(MNM),YPOS(MNM),ZPOS(MNM),RPOS(MNM)
      REAL MFP(MNM),NUMMFP(MNM)  
      COMMON /MFPTEST/ MFP,NUMMFP
      COMMON /STRIKE/ FLAG(MNM),INCI(MNM),SCATTER(MNM),TRACK(MNM),
     &			STRKPOS(MNM),SCATPOS(MNM)
      COMMON /MOAR/ NFLAG(MNM),RLV(MNM)
*
      IF (ABS(GRAV).GT.1.E-6) THEN
        IGRAV=1
      ELSE
        IGRAV=0
      END IF
      IFT=-1
*--a negative IFT indicates that molecules have not entered at this step
      N=0
100   N=N+1
      IF (N.LE.NM) THEN
        IF (IFT.LT.0) AT=DTM
        IF (IFT.GT.0) AT=RF(0)*DTM
*--the time step is a random fraction of DTM for entering molecules
150     MOVT=MOVT+1
        MSC=IPL(N)
        MC=ISC(MSC)
*--MC is the initial cell number
        XI=PP(N)
c        IF ((XI+0.00001*CG(3,1)).LT.XB(1).OR.
c     &   (XI-0.00001*CG(3,MNC)).GT.XB(2)) THEN
c          WRITE (*,*) ' MOL ',N,' OUTSIDE FLOW ',XI
c          CALL REMOVE(N)
c          GO TO 100
c        END IF
       IF ((XI+0.00001*CG(3,1)).LT.XB(1))THEN
          CALL REFLECT1(N,1)
	  INCI(N)=INCI(N)+1.D00
          GO TO 100
       END IF
       IF ((XI-0.00001*CG(3,MNC)).GT.XB(2))THEN
          CALL REFLECT1(N,2)
          GO TO 100
       END IF
c Added by SH 07/10
        DX=PV(1,N)*AT
        IF (IGRAV.EQ.1) DX=DX+0.5*GRAV*AT*AT
        IF (IFX.GT.0) DY=PV(2,N)*AT
        IF (IFX.EQ.2) DZ=PV(3,N)*AT
        X=XI+DX
c
	IF (FLAG(N).EQ.1) THEN
	XPOS(N)=XPOS(N)+ABS(DX)
	YPOS(N)=YPOS(N)+ABS(DY)
	ZPOS(N)=ZPOS(N)+ABS(DZ)
	RPOS(N)=RPOS(N)+SQRT(DX*DX+DY*DY+DZ*DZ)
	END IF
        IF (NFLAG(N).EQ.1) THEN
	RLV(N)=RLV(N)+SQRT(DX*DX+DY*DY+DZ*DZ)
	END IF
	
c Added by SH 07/11
        IF (IFX.NE.0) THEN
*--cylindrical or spherical flow
*--first check for inner boundary interactions
          IF (IB(1).NE.1) THEN
*--there can be no interaction with an axis or centre
            IF (X.LT.XB(1)) THEN
              CALL RBC(IFX,XI,DX,DY,DZ,XB(1),S1)
              IF (S1.LT.1.) THEN
*--collision with inner boundary
                IF (IB(1).GT.3) THEN
*--molecule leaves flow
                  CALL REMOVE(N)
                  GO TO 100
                END IF
                DX=S1*DX
                DY=S1*DY
                DZ=S1*DZ
                CALL AIFX(IFX,XI,DX,DY,DZ,XC,PV(1,N),PV(2,N),PV(3,N))
*--the frame of reference has been rotated with regard to the point of
*----intersection with the inner surface
                IF (IB(1).EQ.2) THEN
*--specular reflection from the boundary
                  PV(1,N)=-PV(1,N)
                  PP(N)=XB(1)+0.001*CG(3,1)
                  AT=AT*(1.-S1)
                  GO TO 150
                END IF
                IF (IB(1).EQ.3) THEN
*--molecule reflects from the surface
                  CALL REFLECT1(N,1)
*--AT is the remaining in the time step for this molecule
                  AT=AT*(1.-S1)
                  GO TO 150
                END IF
              END IF
            END IF
          END IF
          RR=X*X+DY*DY+(IFX-1)*DZ*DZ
          IF (RR.GT.XB(2)*XB(2)) THEN
*--interaction with the outer boundary
            CALL RBC(IFX,XI,DX,DY,DZ,XB(2),S1)
            IF (S1.LT.1.) THEN
*--collision with outer boundary
              IF (IB(2).EQ.4.OR.IB(2).EQ.5) THEN
*--molecule leaves flow
                CALL REMOVE(N)
                GO TO 100
              END IF
*
              IF (IB(2).EQ.6) THEN
c	          CALL REENTER(N)
	          GO TO 100
              END IF
*
              DX=S1*DX
              DY=S1*DY
              DZ=S1*DZ
              CALL AIFX(IFX,XI,DX,DY,DZ,XC,PV(1,N),PV(2,N),PV(3,N))
*--the frame of reference has been rotated with regard to the point of
*----intersection with the outer surface
              IF (IB(2).EQ.2) THEN
*--specular reflection from the boundary
                PV(1,N)=-PV(1,N)
                PP(N)=XB(1)+0.001*CG(3,1)
                AT=AT*(1.-S1)
                GO TO 150
              END IF
              IF (IB(2).EQ.3) THEN
*--molecule reflects from the surface
                CALL REFLECT1(N,2)
*--AT is the remaining in the time step for this molecule
                AT=AT*(1.-S1)
                GO TO 150
              END IF
            END IF
          END IF
*--calculate the end of the trajectory
          CALL AIFX(IFX,XI,DX,DY,DZ,X,PV(1,N),PV(2,N),PV(3,N))
*  plane flow
*--molecule N at XI is moved by DX to X
        ELSE IF (X.LT.XB(1).OR.X.GT.XB(2)) THEN
          IF (X.LT.XB(1)) K=1
          IF (X.GT.XB(2)) K=2
*--intersection with inner, outer boundary for K=1, 2
          IF (IB(K).EQ.2) THEN
*--specular reflection from the boundary (eqn (11.7))
            X=2.*XB(K)-X
            PV(1,N)=-PV(1,N)
          END IF
          IF (IB(K).GT.3) THEN
*--molecule leaves flow
*            CALL REMOVE(N)
            GO TO 100
          END IF
          IF (IB(K).EQ.3) THEN
*--AT is the remaining in the time step for this molecule
            AT=AT-(XB(K)-XI)/PV(1,N)
*--molecule reflects from the surface
            CALL REFLECT1(N,K)
            GO TO 150
          END IF
*--no boundary interactions
        END IF
*
        IF (X.LT.CG(1,MC).OR.X.GT.CG(2,MC)) THEN
*--the molecule has moved from the initial cell
          IF (IFC.EQ.0) THEN
            MC=(X-XB(1))/CW+0.99999
          ELSE
            XD=(X-XB(1))/FW+1.E-6
            MC=1.+(LOG(1.-XD*AP))/RP
*--the cell number is calculated from eqn (12.1)
          END IF
          IF (MC.LT.1) MC=1
          IF (MC.GT.MNC) MC=MNC
*--MC is the new cell number (note avoidance of round-off error)
        END IF
        MSC=((X-CG(1,MC))/CG(3,MC))*(NSC-.001)+1+NSC*(MC-1)
*--MSC is the new sub-cell number
        IF (MSC.LT.1) MSC=1
        IF (MSC.GT.MNSC) MSC=MNSC
        IPL(N)=MSC
        PP(N)=X
        IF (IGRAV.EQ.1) PV(1,N)=PV(1,N)+GRAV*AT
        GO TO 100
      ELSE IF (IFT.LT.0) THEN
        IFT=1
*--new molecules enter
        CALL ENTER1
        N=N-1
        GO TO 100
      END IF
      RETURN
      END
*   ENTER1.FOR
*
      SUBROUTINE ENTER1
*
*--new molecules enter at boundaries
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
      COMMON /CONST / PI,SPI,BOLTZ
*
      DO 100 N=1,2
*--consider each boundary in turn
        DO 50 L=1,MNSP
*--consider each species in turn
          A=BME(N,L)+BMR(N,L)
          M=A
          BMR(N,L)=A-M 
*         WRITE (*,99010) A,BMR(N,L)
*99010    FORMAT ('A',E12.4,'     BMR',E12.4)          
*--M molecules enter, remainder has been reset
          IF (M.GT.0) THEN
            VMP=SQRT(2.*BOLTZ*BFTMP(N)/SP(5,L))
            IF (ABS(BVFX(N)).GT.1.E-6) THEN
              IF (N.EQ.1) SC=BVFX(N)/VMP
              IF (N.EQ.2) SC=-BVFX(N)/VMP
              FS1=SC+SQRT(SC*SC+2.)
              FS2=0.5*(1.+SC*(2.*SC-FS1))
            END IF
* the above constants are required for the entering distn. of eqn (12.5)
            DO 10 K=1,M
              IF (NM.LT.MNM) THEN
                NM=NM+1
*--NM is now the number of the new molecule
                IF (ABS(BVFX(N)).GT.1.E-6) THEN
                  QA=3.
                  IF (SC.LT.-3.) QA=ABS(SC)+1.
2                 U=-QA+2.*QA*RF(0)
*--U is a potential normalised thermal velocity component
                  UN=U+SC
*--UN is a potential inward velocity component
                  IF (UN.LT.0.) GO TO 2
                  A=(2.*UN/FS1)*EXP(FS2-U*U)
                  IF (A.LT.RF(0)) GO TO 2
*--the inward normalised vel. component has been selected (eqn (12.5))
                  IF (N.EQ.1) PV(1,NM)=UN*VMP
                  IF (N.EQ.2) PV(1,NM)=-UN*VMP
                ELSE
                  IF (N.EQ.1) PV(1,NM)=SQRT(-LOG(RF(0)))*VMP
                  IF (N.EQ.2) PV(1,NM)=-SQRT(-LOG(RF(0)))*VMP
*--for a stationary external gas, use eqn (12.3)
                END IF
                CALL RVELC(PV(2,NM),PV(3,NM),VMP)
*--a single call of RVELC generates the two normal velocity components
                IF (ISPR(1,L).GT.0) CALL SROT(PR(NM),BFTMP(N),ISPR(1,L))
                IF (N.EQ.1) PP(NM)=XB(1)+0.001*CG(3,1)
                IF (N.EQ.2) PP(NM)=XB(2)-0.001*CG(3,MNC)
*--the molecule is moved just off the boundary
                IPS(NM)=L
                IF (N.EQ.1) IPL(NM)=1
                IF (N.EQ.2) IPL(NM)=MNSC
              ELSE
                WRITE (*,*) 
     &' WARNING: EXCESS MOLECULE LIMIT - RESTART WITH AN INCREASED FNUM'
              END IF
10          CONTINUE
          END IF
50      CONTINUE
100   CONTINUE
      RETURN
      END
*   REFLECT1.FOR
      SUBROUTINE REFLECT1(N,K)
*
*--diffuse reflection of molecule N from surface K
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSS(8,2,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPS / CSS
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
      COMMON /CONST / PI,SPI,BOLTZ
      COMMON /INNERBOUN/ ALFNORM,ALFTANG
      COMMON /STRIKE/ FLAG(MNM),INCI(MNM),SCATTER(MNM),TRACK(MNM),
     &			STRKPOS(MNM),SCATPOS(MNM)
      COMMON /CARTE/ XPOS(MNM),YPOS(MNM),ZPOS(MNM),RPOS(MNM)
      COMMON /MOAR/ NFLAG(MNM),RLV(MNM)
*
      L=IPS(N)
*--sample the surface properies due to the incident molecules
      CSS(1,K,L)=CSS(1,K,L)+1.
      IF (K.EQ.1) CSS(2,K,L)=CSS(2,K,L)-SP(5,L)*PV(1,N)
      IF (K.EQ.2) CSS(2,K,L)=CSS(2,K,L)+SP(5,L)*PV(1,N)
      CSS(4,K,L)=CSS(4,K,L)+SP(5,L)*(PV(2,N)-BVY(K))
      CSS(5,K,L)=CSS(5,K,L)+0.5*SP(5,L)
     &           *(PV(1,N)**2+(PV(2,N)-BVY(K))**2+PV(3,N)**2)
      CSS(7,K,L)=CSS(7,K,L)+PR(N)
*
      VMP=SQRT(2.*BOLTZ*BT(K)/SP(5,L))
      VMG=SQRT(2.*BOLTZ*BT(2)/SP(5,L))
*--VMP is the most probable speed in species L, see eqns (4.1) and (4.7)
c      IF (K.EQ.1) THEN
c        PV(1,N)=SQRT(-LOG(RF(0)))*VMP
c         CALL RVELC(PV(2,N),PV(3,N),VMP)
c           STRKPOS(N)=ABS(PP(N)-TRACK(N))
c	   FLAG(N)=1
c          SCATPOS(N)=PP(N)
c      END IF

      IF (K.EQ.1) THEN
	   IF ((RF(0)-0.3).GT.1.E-9) THEN
		PV(1,N)=-PV(1,N)					
	   ELSE
	    	PV(1,N)=SQRT(-LOG(RF(0)))*VMP
	        CALL RVELC(PV(2,N),PV(3,N),VMP)
	   END IF
           STRKPOS(N)=ABS(PP(N)-TRACK(N))
	   FLAG(N)=1
	   NFLAG(N)=0
	   INCI(N)=INCI(N)+1
           SCATPOS(N)=PP(N)
      END IF
c      IF (K.EQ.1) THEN
c         IF((RF(0)-ALFNORM).GT.1.E-6) THEN
c            PV(1,N)=-PV(1,N)
c         ELSE
c            CALL CLL(PV(1,N),PV(2,N),PV(3,N),VMP)
c         END IF
c	  CALL RVELC(PV(2,N),PV(3,N),VMP)
c	   STRKPOS(N)=ABS(PP(N)-TRACK(N))
c	   FLAG(N)=1
c           SCATPOS(N)=PP(N)
c      END IF
c Added by SH
      IF (K.EQ.2) THEN 
        PV(1,N)=-SQRT(-LOG(RF(0)))*VMP
*--the normal velocity component has been generated (eqn(12.3))
        CALL RVELC(PV(2,N),PV(3,N),VMP)
*--a single call of RVELC generates the two tangential velocity components
      END IF
      PV(2,N)=PV(2,N)+BVY(K)
      IF (ISPR(1,L).GT.0) CALL SROT(PR(N),BT(K),ISPR(1,L))
      IF (K.EQ.1) PP(N)=XB(1)+0.001*CG(3,1)
      IF (K.EQ.2) PP(N)=XB(2)-0.001*CG(3,MNC)
*--the molecule is moved just off the boundary
      IF (K.EQ.1) IPL(N)=1
      IF (K.EQ.2) IPL(N)=MNSC
*--sample the surface properties due to the reflected molecules
      IF (K.EQ.1) CSS(3,K,L)=CSS(3,K,L)+SP(5,L)*PV(1,N)
      IF (K.EQ.2) CSS(3,K,L)=CSS(3,K,L)-SP(5,L)*PV(1,N)
      CSS(6,K,L)=CSS(6,K,L)-0.5*SP(5,L)
     &           *(PV(1,N)**2+(PV(2,N)-BVY(K))**2+PV(3,N)**2)
      CSS(8,K,L)=CSS(8,K,L)-PR(N)
      RETURN
      END
*   REMOVE.FOR
      SUBROUTINE REMOVE(N)
*
*--remove molecule N and replace it by molecule NM
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
*
      PP(N)=PP(NM)
      DO 100 M=1,3
        PV(M,N)=PV(M,NM)
100   CONTINUE
*        PV(1,N)=-PV(1,MN) added by SH
      PR(N)=PR(NM)
      IPL(N)=IPL(NM)
      IPS(N)=IPS(NM)
      NM=NM-1
      N=N-1
      RETURN
      END
*   SAMPI1.FOR
*
      SUBROUTINE SAMPI1
*
*--initialises all the sampling variables
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSR(MNC,MNSP)
      DOUBLE PRECISION CSS(8,2,MNSP)
      DOUBLE PRECISION CSH(4,MNC,MNSP)
*
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPR / CSR
      COMMON /SAMPS / CSS
      COMMON /SAMPH / CSH
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
*
      NSMP=0
      TIMI=TIME
      DO 200 L=1,MNSP
        DO 50 N=1,MNC
          CS(1,N,L)=1.E-6
          DO 20 M=2,7
            CS(M,N,L)=0.
20        CONTINUE
          DO 40 M=1,4
            CSH(M,N,L)=0.
40        CONTINUE
          CSR(N,L)=0.
50      CONTINUE
        DO 100 N=1,2
          CSS(1,N,L)=1.E-6
          DO 60 M=2,8
            CSS(M,N,L)=0.
60        CONTINUE
100     CONTINUE
200   CONTINUE
      RETURN
      END
*   SAMPLE1.FOR
*
      SUBROUTINE SAMPLE1
*
*--sample the molecules in the flow.
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSR(MNC,MNSP)
      DOUBLE PRECISION CSH(4,MNC,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPR / CSR
      COMMON /SAMPH / CSH
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
*
      NSMP=NSMP+1
      DO 100 NN=1,MNSG
        DO 50 N=1,MNC
          L=IC(2,N,NN)
          IF (L.GT.0) THEN
            DO 10 J=1,L
              K=IC(1,N,NN)+J
              M=IR(K)
              I=IPS(M)
              CS(1,N,I)=CS(1,N,I)+1
              CSQ=0.
              DO 5 LL=1,3
                CS(LL+1,N,I)=CS(LL+1,N,I)+PV(LL,M)
                CS(LL+4,N,I)=CS(LL+4,N,I)+PV(LL,M)**2
                CSQ=CSQ+PV(LL,M)**2
5             CONTINUE
              CSR(N,I)=CSR(N,I)+PR(M)
              CSH(1,N,I)=CSH(1,N,I)+PV(1,M)*PV(2,M)
              CSH(2,N,I)=CSH(2,N,I)+CSQ*PV(1,M)
              CSH(3,N,I)=CSH(3,N,I)+PR(M)*PV(1,M)
              CSH(4,N,I)=CSH(4,N,I)+PV(1,M)*PV(3,M)
10          CONTINUE
          END IF
50      CONTINUE
100   CONTINUE
      RETURN
      END
*   OUT1.FOR
*
*
      SUBROUTINE OUT1(N_NU_H)
*
*--output a progressive set of results to file DSMC1.OUT.
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSR(MNC,MNSP)
      DOUBLE PRECISION CSS(8,2,MNSP)
      DOUBLE PRECISION CSH(4,MNC,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPR / CSR
      COMMON /SAMPS / CSS
      COMMON /SAMPH / CSH
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /CONST / PI,SPI,BOLTZ
      COMMON /FREQ / XRELV(MNC),NSAMP(MNC),COLRATE(MNC),RELV
      REAL NU_H(1000000),SPD(1000000)
      DOUBLE PRECISION TDELTA,TA,TB,DIFF,QSAMP
      COMMON /OUTERBOUN/ HCOND0,QAVE,NU_H,Q_CON,SPD
      COMMON /LAWKEL/ SLOPE(100000)
      COMMON /STRIKE/ FLAG(MNM),INCI(MNM),SCATTER(MNM),TRACK(MNM),
     &			STRKPOS(MNM),SCATPOS(MNM)
      REAL MFP(MNM),NUMMFP(MNM) 
      COMMON /MFPTEST/ MFP,NUMMFP
      DOUBLE PRECISION VEL(3),SMU(3),SVEL(3,MNC),SN,SM,SMCC,SRDF,SRE,TT,
     &                 TROT,DBOLTZ,SS(8),SUV,SCCU,SRU,SUU
      COMMON /CARTE/ XPOS(MNM),YPOS(MNM),ZPOS(MNM),RPOS(MNM)
      COMMON /MOAR/ NFLAG(MNM),RLV(MNM)
      DBOLTZ=BOLTZ
*
      OPEN (4,FILE='OUT_9E27_t2516.txt',FORM='FORMATTED')
*
      WRITE (4,*) ' FLOW SAMPLED FROM TIME ',TIMI,' TO TIME ',TIME
      WRITE (4,*) ' COLLISIONS:-'
      WRITE (4,99001) ((IDINT(COL(M,L)),M=1,MNSP),L=1,MNSP)
99001 FORMAT (5I12)
      WRITE (4,*) ' TOTAL NUMBER OF SAMPLES ',NSMP
      WRITE (4,*) NM,' MOLECULES'
      WRITE (4,*) MOVT,' TOTAL MOLECULAR MOVES'
      IF (NCOL.GT.0) THEN
        WRITE (4,*) INT(SELT),' SELECTIONS ',INT(NCOL),
     &              ' COLLISION EVENTS, RATIO  ',REAL(NCOL/SELT)
        IF (NCOL.GT.0) WRITE (4,*) ' MEAN COLLISION SEPARATION ',
     &                             REAL(SEPT/NCOL)
      END IF
*
      DO 100 K=1,2
        IF (IB(K).EQ.3) THEN
          IF (K.EQ.1) WRITE (4,*) ' INNER SURFACE PROPERTIES '
          IF (K.EQ.2) WRITE (4,*) ' OUTER SURFACE PROPERTIES '
          IF (IFX.EQ.0) A=FNUM/(TIME-TIMI)
          IF (IFX.EQ.1) A=FNUM/((TIME-TIMI)*2.*PI*XB(K))
          IF (IFX.EQ.2) A=FNUM/((TIME-TIMI)*4.*PI*XB(K)*XB(K))
          DO 20 N=1,8
            SS(N)=0.
            DO 10 L=1,MNSP
              SS(N)=SS(N)+CSS(N,K,L)
10          CONTINUE

20        CONTINUE
          WRITE (4,*) ' SAMPLE  FRACTION SPECIES 1,  SPECIES 2....'
          WRITE (4,99002) SS(1),(CSS(1,K,L)/SS(1),L=1,MNSP)
99002     FORMAT (F12.1,6F12.6)
          DO 40 N=1,8
            SS(N)=SS(N)*A
40        CONTINUE
          WRITE (4,*) ' NUM FLUX INC PRESS REFL PRESS SHEAR STR '
          WRITE (4,99003) (SS(N),N=1,4)
99003     FORMAT (6E12.5)
          WRITE (4,*) 
     & ' INC TR EN  REFL TR EN  INC ROT EN  REFL ROT EN NET HEAT FLUX  '
          WRITE (4,99003) (SS(N),N=5,8),SS(5)+SS(6)+SS(7)+SS(8)
        END IF
100   CONTINUE
*
      WRITE (4,*) 'SAMPLES'
      WRITE (4,*) ' CELL     N SP 1    N SP 2     ETC '
      DO 200 N=1,MNC
        WRITE (4,99004) N,(IDINT(CS(1,N,L)),L=1,MNSP)
200   CONTINUE
99004 FORMAT (' ',I6,5I9)
*
      WRITE (4,*) ' FLOWFIELD PROPERTIES'
      WRITE (4,*) 
     &'  CELL   X COORD     DENSITY   TR TEMP  ROT TEMP   OV TEMP      U
     &         V           W   SHEAR STRESS    HEAT FLUX'
*--first the mixture properties

      QAVE=0.0
      QSAMP=0.0

      DO 400 N=1,MNC
        A=FNUM/(CC(N)*NSMP)
        SN=0.
        SM=0.
        DO 250 K=1,3
          SMU(K)=0.
250     CONTINUE
        SMCC=0.
        SRE=0.
        SRDF=0.
         SUU=0.
        SUV=0.
         SUW=0.
        SCCU=0.
        SRU=0.
        DO 300 L=1,MNSP
          SN=SN+CS(1,N,L)
*--SN is the number sum
          SM=SM+SP(5,L)*CS(1,N,L)
*--SM is the sum of molecular masses
          DO 260 K=1,3
            SMU(K)=SMU(K)+SP(5,L)*CS(K+1,N,L)
*--SMU(1 to 3) are the sum of mu, mv, mw
260       CONTINUE
          SMCC=SMCC+(CS(5,N,L)+CS(6,N,L)+CS(7,N,L))*SP(5,L)
*--SMCC is the sum of m(u**2+v**2+w**2)
          SRE=SRE+CSR(N,L)
*--SRE is the sum of rotational energy
          SRDF=SRDF+ISPR(1,L)*CS(1,N,L)
*--SRDF is the sum of the rotational degrees of freedom
          SUU=SUU+SP(5,L)*CS(5,N,L)
*--SUU is the sum of m*u*u
          SUV=SUV+SP(5,L)*CSH(1,N,L)
          SUW=SUW+SP(5,L)*CSH(4,N,L)
*--SUV is the sum of m*u*v
          SCCU=SCCU+SP(5,L)*CSH(2,N,L)
*--SCCU is the sum of m*c**2*u
          SRU=SRU+CSH(3,N,L)
*--SRU is the sum of rotl. energy * u
300     CONTINUE
        DENN=SN*A
c        SPD(N_NU_H)=DENN
*--DENN is the number density, see eqn (1.34)
        DEN=DENN*SM/SN
*--DEN is the density, see eqn (1.42)
        DO 350 K=1,3
          VEL(K)=SMU(K)/SM
          SVEL(K,N)=VEL(K)
350     CONTINUE
*--VEL and SVEL are the stream velocity components, see eqn (1.43)
        UU=VEL(1)**2+VEL(2)**2+VEL(3)**2
        TT=(SMCC-SM*UU)/(3.D00*DBOLTZ*SN)
*--TT is the translational temperature, see eqn (1.51)
        IF (SRDF.GT.1.E-6) TROT=(2.D00/DBOLTZ)*SRE/SRDF
*--TROT is the rotational temperature, see eqn (11.11)
        TEMP=(3.D00*TT+(SRDF/SN)*TROT)/(3.+SRDF/SN)
*--TEMP is the overall temperature, see eqn (11.12)
        CT(N)=TEMP
        TXY=-DENN*SUV/SN
*--TXY is the xy component of shear stress (see eqn (12.13))
c       QX=DENN*(0.5*SCCU-SUV*VEL(2)-(SUU-SM*VEL(1)**2+0.5*SMCC+SRE)
c     &     *VEL(1)+SRU)/SN
	QX=DENN*(0.5*SCCU-SUV*VEL(2)-SUW*VEL(3)
     #	  -(SUU-SM*UU+0.5*SMCC+SRE)
     &     *VEL(1)+SRU)/SN
*--QX is the x component of the heat flux vector (see eqn (12.14))
        XC=0.5*(CG(1,N)+CG(2,N))
*--XC is the x coordinate of the midpoint of the cell
        WRITE (4,99005) N,XC,DEN,TT,TROT,TEMP,VEL(1),VEL(2),VEL(3),TXY,
     &                  QX,CS(2,N,1)
99005   FORMAT (' ',I5,E12.4,1P,E12.4,0P,6F10.4,2E12.4,1P,E12.4)
*
*      QAVE=QAVE+4.*PI*XC**2*QX  
      QSAMP=QSAMP+4.*PI*XC**2*QX
c      SPD(N_NU_H)=SPD(N_NU_H)+DENN
400   CONTINUE
*
*      QAVE=QAVE/MNC
      QSAMP=QSAMP/MNC

*
      NU_H(N_NU_H)=QSAMP/(2.*PI*XB(1)*HCOND0*(BT(1)-300.))
      SPD(N_NU_H)=0.0

      IF(MOD(NPR,100).EQ.0.0)THEN
       IF (ABS(SLOPE(NPR/100)).LT.1.0E-3) THEN
          SPD(N_NU_H)=NU_H(N_NU_H)
       END IF
      END IF


      DIFF=1.0
      TA=300.
      TB=3000.
      TDELTA=0.0
c      IF (NPR.GT.50000)THEN
      IF(MOD(NPR,100).EQ.0.0)THEN
       IF (ABS(SLOPE(NPR/100)).LT.1.0E-3) THEN
        DO WHILE ((ABS(DIFF).GT.1.E-6).AND.(QSAMP.GT.0.0))
         TDELTA=(TB-TA)/(DELTA(TB)-DELTA(TA))*
     &         (QSAMP+DELTA(TB))
         TA=TB
         WRITE (*,99010) DIFF,TDELTA
99010    FORMAT ('DIFF',E12.4,'TDELTA',E12.4)
        TB=TB-TDELTA
        DIFF=QSAMP+DELTA(TB)
        END DO
*      
         IF (QSAMP.GT.0.0)THEN
         BT(2)=TB
	WRITE (*,99011) TB
99011    FORMAT ('BT(2)',E12.4)
c*         BT(2)=300. 
         ELSE
         BT(2)=300.
         END IF
       END IF
      END IF

      WRITE (4,*)
      DO 500 L=1,MNSP
*--now the properties of the separate species
        WRITE (4,*) ' SPECIES ',L
        WRITE (4,*) 
     &' CELL   X COORD      N DENS     DENSITY     TTX       TTY       T
     &TZ    TR TEMP   ROT TEMP    TEMP   U DIF VEL V DIF VEL W DIF VEL '
        DO 450 N=1,MNC
          A=FNUM/(CC(N)*NSMP)
          DENN=CS(1,N,L)*A
*--DENN is the partial number density
          DEN=SP(5,L)*DENN
*--DEN is the partial density, see eqn (1.13)
          DO 420 K=1,3
            VEL(K)=CS(K+1,N,L)/CS(1,N,L)
*--VEL defines the average velocity of the species L molecules
420       CONTINUE
          UU=VEL(1)**2+VEL(2)**2+VEL(3)**2
          TTX=(SP(5,L)/DBOLTZ)*(CS(5,N,L)/CS(1,N,L)-VEL(1)**2)
          TTY=(SP(5,L)/DBOLTZ)*(CS(6,N,L)/CS(1,N,L)-VEL(2)**2)
          TTZ=(SP(5,L)/DBOLTZ)*(CS(7,N,L)/CS(1,N,L)-VEL(3)**2)
*--the component temperatures are based on eqn (1.30)
          TT=(SP(5,L)/(3.D00*DBOLTZ))
     &       *((CS(5,N,L)+CS(6,N,L)+CS(7,N,L))/CS(1,N,L)-UU)
*--TT is the translational temperature, see eqn (1.29)
          IF (ISPR(1,L).GT.0) THEN
            TROT=2.D00*CSR(N,L)/(ISPR(1,L)*DBOLTZ*CS(1,N,L))
          ELSE
            TROT=0.
          END IF
*--TROT is the rotational temperature, see eqn (11.10)
          TEMP=(3.D00*TT+ISPR(1,L)*TROT)/(3.+ISPR(1,L))
          DO 440 K=1,3
            VEL(K)=VEL(K)-SVEL(K,N)
*--VEL now defines the diffusion velocity of species L, see eqn (1,45)
440       CONTINUE
          XC=0.5*(CG(1,N)+CG(2,N))
          WRITE (4,99006) N,XC,DENN,DEN,TTX,TTY,TTZ,TT,TROT,TEMP,VEL(1),
     &                    VEL(2),VEL(3)
99006     FORMAT (' ',I5,F9.4,1P,2E12.4,0P,9E12.4)
450     CONTINUE
500   CONTINUE
*
*
      CLOSE (4)

      IF(MOD(NPR,1000).EQ.0.0) THEN
       OPEN(4,FILE='Position_9E27.txt',FORM='FORMATTED')
	 DO 5 I=1,NM
	   WRITE(4,996) I,STRKPOS(I),SCATTER(I),MFP(I)/NUMMFP(I)
5      CONTINUE
996    FORMAT (' ',I16,2P,E12.4,2P,E12.4,2P,E12.4)
       CLOSE(4)
      ENDIF
*
      IF(MOD(NPR,1000).EQ.0.0) THEN
       OPEN(4,FILE='NuH_9E27.txt',FORM='FORMATTED')
	 DO 7 I=1,NPT
	   WRITE(4,998) I, NU_H(I)
7        CONTINUE
998    FORMAT (' ',I16,1P,E12.4)
       CLOSE(4)
      ENDIF

      IF(NPR.EQ.NPT) THEN
        OPEN(4,FILE='avgcf_9E27.txt',FORM='FORMATTED')
          DO 8 I=1,MNC
             WRITE(4,995) XRELV(I),COLRATE(I)
8         CONTINUE
995     FORMAT (' ',E12.4,2P,E12.4)
        CLOSE(4)
      END IF

      IF(MOD(NPR,1000).EQ.0.0) THEN
       OPEN(4,FILE='SPD_9E27.txt',FORM='FORMATTED')
	 DO 9 I=1,NPT
	   WRITE(4,994) I, SPD(I)
9        CONTINUE
994    FORMAT (' ',I16,1P,E12.4)
       CLOSE(4)
      ENDIF

c       IF(MOD(NPR,1000).EQ.0.0) THEN
c       OPEN(4,FILE='cartesian_9E26.txt',FORM='FORMATTED')
c	 DO 11 I=1,NM
c	   WRITE(4,993) I, XPOS(I),YPOS(I),ZPOS(I),RPOS(I)/INCI(I)
c11        CONTINUE
c993    FORMAT (' ',I16,2P,E12.4,2P,E12.4,2P,E12.4,2P,E12.4)
c       CLOSE(4)
c      ENDIF
c      RETURN
c      END

       IF(MOD(NPR,1000).EQ.0.0) THEN
       OPEN(4,FILE='outgoing_9E27.txt',FORM='FORMATTED')
	 DO 11 I=1,NM
	   WRITE(4,993) I,RPOS(I)/INCI(I)
11        CONTINUE
993    FORMAT (' ',I16,2P,E12.4)
       CLOSE(4)
      ENDIF

      IF(MOD(NPR,1000).EQ.0.0) THEN
       OPEN(4,FILE='incoming_9E27.txt',FORM='FORMATTED')
	 DO 12 I=1,NM
	   WRITE(4,992) I,RLV(I)/INCI(I)
12        CONTINUE
992    FORMAT (' ',I16,2P,E12.4)
       CLOSE(4)
      ENDIF
      RETURN
      END

*   SROT.FOR
*
      SUBROUTINE SROT(PR,TEMP,IDF)
*--selects a typical equuilibrium value of the rotational energy PR at
*----the temperature TEMP in a gas with IDF rotl. deg. of f.
*
      COMMON /CONST / PI,SPI,BOLTZ
 
      IF (IDF.EQ.2) THEN
        PR=-LOG(RF(0))*BOLTZ*TEMP
*--for 2 degrees of freedom, the sampling is directly from eqn (11.22)
      ELSE
*--otherwise apply the acceptance-rejection method to eqn (11.23)
        A=0.5*IDF-1.
50      ERM=RF(0)*10.
*--the cut-off internal energy is 10 kT
        B=((ERM/A)**A)*EXP(A-ERM)
        IF (B.LT.RF(0)) GO TO 50
        PR=ERM*BOLTZ*TEMP
      END IF
      RETURN
      END
*   RBC.FOR
*
      SUBROUTINE RBC(IFX,XI,DX,DY,DZ,R,S)
*--calculates the trajectory fraction S from a point at radius XI with
*----displacements DX, DY, and DZ to a possible intersection with a
*----surface of radius R, IFX=1, 2 for cylindrical, spherical geometry
      DD=DX*DX+DY*DY
      IF (IFX.EQ.2) DD=DD+DZ*DZ
      B=XI*DX/DD
      C=(XI*XI-R*R)/DD
      A=B*B-C
      IF (A.GE.0.) THEN
*--find the least positive solution to the quadratic
        A=SQRT(A)
        S1=-B+A
        S2=-B-A
        IF (S2.LT.0.) THEN
          IF (S1.GT.0.) THEN
            S=S1
          ELSE
            S=2.
          END IF
        ELSE IF (S1.LT.S2) THEN
          S=S1
        ELSE
          S=S2
        END IF
      ELSE
        S=2.
*--setting S to 2 indicates that there is no intersection
      END IF
      RETURN
      END
*   AIFX.FOR
*
      SUBROUTINE AIFX(IFX,XI,DX,DY,DZ,X,U,V,W)
*--calculates the new radius and realigns the velocity components in
*----cylindrical (IFX=1) and spherical (IFX=2) flows
      IF (IFX.EQ.1) THEN
        DR=DY
        VR=V
      ELSE IF (IFX.EQ.2) THEN
        DR=SQRT(DY*DY+DZ*DZ)
        VR=SQRT(V*V+W*W)
      END IF
      A=XI+DX
      X=SQRT(A*A+DR*DR)
      S=DR/X
      C=A/X
      B=U
      U=B*C+VR*S
      V=-B*S+VR*C
      IF (IFX.EQ.2) THEN
        VR=V
        A=6.2831853*RF(0)
        V=VR*SIN(A)
        W=VR*COS(A)
      END IF
      RETURN
      END
*   ERF.FOR
*
      FUNCTION ERF(S)
*
*--calculates the error function of S
*
      B=ABS(S)
      IF (B.GT.4.) THEN
        D=1.
      ELSE
        C=EXP(-B*B)
        T=1./(1.+0.3275911*B)
        D=1.-(0.254829592*T-0.284496736*T*T+1.421413741*T*T*T-
     &    1.453152027*T*T*T*T+1.061405429*T*T*T*T*T)*C
      END IF
      IF (S.LT.0.) D=-D
      ERF=D
      RETURN
      END
*   INDEXM.FOR
*
*--end of listing
*
*
      SUBROUTINE INDEXM
*
*--the NM molecule numbers are arranged in order of the molecule groups
*--and, within the groups, in order of the cells and, within the cells,
*--in order of the sub-cells
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
*
      DO 200 MM=1,MNSG
        IG(2,MM)=0
        DO 50 NN=1,MNC
          IC(2,NN,MM)=0
50      CONTINUE
        DO 100 NN=1,MNSC
          ISCG(2,NN,MM)=0
100     CONTINUE
200   CONTINUE
      DO 300 N=1,NM
        LS=IPS(N)
        MG=ISP(LS)
        IG(2,MG)=IG(2,MG)+1
        MSC=IPL(N)
        ISCG(2,MSC,MG)=ISCG(2,MSC,MG)+1
        MC=ISC(MSC)
        IC(2,MC,MG)=IC(2,MC,MG)+1
300   CONTINUE
*--number in molecule groups in the cells and sub-cells have been counte
      M=0
      DO 400 L=1,MNSG
        IG(1,L)=M
*--the (start address -1) has been set for the groups
        M=M+IG(2,L)
400   CONTINUE
      DO 600 L=1,MNSG
        M=IG(1,L)
        DO 450 N=1,MNC
          IC(1,N,L)=M
          M=M+IC(2,N,L)
450     CONTINUE
*--the (start address -1) has been set for the cells
        M=IG(1,L)
        DO 500 N=1,MNSC
          ISCG(1,N,L)=M
          M=M+ISCG(2,N,L)
          ISCG(2,N,L)=0
500     CONTINUE
600   CONTINUE
*--the (start address -1) has been set for the sub-cells
 
      DO 700 N=1,NM
        LS=IPS(N)
        MG=ISP(LS)
        MSC=IPL(N)
        ISCG(2,MSC,MG)=ISCG(2,MSC,MG)+1
        K=ISCG(1,MSC,MG)+ISCG(2,MSC,MG)
        IR(K)=N
*--the molecule number N has been set in the cross-reference array
700   CONTINUE
      RETURN
      END
*   SELECT.FOR
*
      SUBROUTINE SELECT
*--selects a potential collision pair and calculates the product of the
*--collision cross-section and relative speed
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /CONST / PI,SPI,BOLTZ
      COMMON /ELAST / VRC(3),VRR,VR,L,M,LS,MS,CVR,MM,NN,N
*      COMMON /FREQ / XRELV(MNC),NSAMP(MNC),COLRATE(MNC),RELV
*      DOUBLE PRECISION  XRELV(MNC),NSAMP(MNC),COLRATE(MNC),RELV
  
      K=INT(RF(0)*(IC(2,N,NN)-0.001))+IC(1,N,NN)+1
      L=IR(K)
*--the first molecule L has been chosen at random from group NN in cell
100   MSC=IPL(L)
      IF ((NN.EQ.MM.AND.ISCG(2,MSC,MM).EQ.1).OR.
     &    (NN.NE.MM.AND.ISCG(2,MSC,MM).EQ.0)) THEN
*--if MSC has no type MM molecule find the nearest sub-cell with one
        NST=1
        NSG=1
150     INC=NSG*NST
        NSG=-NSG
        NST=NST+1
        MSC=MSC+INC
        IF (MSC.LT.1.OR.MSC.GT.MNSC) GO TO 150
        IF (ISC(MSC).NE.N.OR.ISCG(2,MSC,MM).LT.1) GO TO 150
      END IF
*--the second molecule M is now chosen at random from the group MM
*--molecules that are in the sub-cell MSC
      K=INT(RF(0)*(ISCG(2,MSC,MM)-0.001))+ISCG(1,MSC,MM)+1
      M=IR(K)
      IF (L.EQ.M) GO TO 100
*--choose a new second molecule if the first is again chosen
*
      DO 200 K=1,3
        VRC(K)=PV(K,L)-PV(K,M)
200   CONTINUE
*--VRC(1 to 3) are the components of the relative velocity
      VRR=VRC(1)**2+VRC(2)**2+VRC(3)**2
      VR=SQRT(VRR)
*--VR is the relative speed
      LS=IPS(L)
      MS=IPS(M)
      CVR=VR*SPM(1,LS,MS)*((2.*BOLTZ*SPM(2,LS,MS)/(SPM(5,LS,MS)*VRR))
     &    **(SPM(3,LS,MS)-0.5))/SPM(6,LS,MS)
*--the collision cross-section is based on eqn (4.63)
      RETURN
      END
*   ELASTIC.FOR
*
      SUBROUTINE ELASTIC
*
*--generate the post-collision velocity components.
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /CONST / PI,SPI,BOLTZ
      COMMON /ELAST / VRC(3),VRR,VR,L,M,LS,MS,CVR,MM,NN,N
*
      DIMENSION VRCP(3),VCCM(3)
*--VRCP(3) are the post-collision components of the relative velocity
*--VCCM(3) are the components of the centre of mass velocity
*
      RML=SPM(5,LS,MS)/SP(5,MS)
      RMM=SPM(5,LS,MS)/SP(5,LS)
      DO 100 K=1,3
        VCCM(K)=RML*PV(K,L)+RMM*PV(K,M)
100   CONTINUE
*--VCCM defines the components of the centre-of-mass velocity, eqn (2.1)
      IF (ABS(SPM(4,LS,MS)-1.).LT.1.E-3) THEN
*--use the VHS logic
        B=2.*RF(0)-1.
*--B is the cosine of a random elevation angle
        A=SQRT(1.-B*B)
        VRCP(1)=B*VR
        C=2.*PI*RF(0)
*--C is a random azimuth angle
        VRCP(2)=A*COS(C)*VR
        VRCP(3)=A*SIN(C)*VR
      ELSE
*--use the VSS logic
        B=2.*(RF(0)**SPM(4,LS,MS))-1.
*--B is the cosine of the deflection angle for the VSS model, eqn (11.8)
        A=SQRT(1.-B*B)
        C=2.*PI*RF(0)
        OC=COS(C)
        SC=SIN(C)
        D=SQRT(VRC(2)**2+VRC(3)**2)
        IF (D.GT.1.E-6) THEN
          VRCP(1)=B*VRC(1)+A*SC*D
          VRCP(2)=B*VRC(2)+A*(VR*VRC(3)*OC-VRC(1)*VRC(2)*SC)/D
          VRCP(3)=B*VRC(3)-A*(VR*VRC(2)*OC+VRC(1)*VRC(3)*SC)/D
        ELSE

          VRCP(1)=B*VRC(1)
          VRCP(2)=A*OC*VRC(1)

          VRCP(3)=A*SC*VRC(1)
        END IF
*--the post-collision rel. velocity components are based on eqn (2.22)
      END IF
*--VRCP(1 to 3) are the components of the post-collision relative vel.
      DO 200 K=1,3
        PV(K,L)=VCCM(K)+VRCP(K)*RMM
        PV(K,M)=VCCM(K)-VRCP(K)*RML
200   CONTINUE
      RETURN
      END
*   RVELC.FOR
*
      SUBROUTINE RVELC(U,V,VMP)
*
*--generates two random velocity components U an V in an equilibrium
*--gas with most probable speed VMP  (based on eqns (C10) and (C12))
*
      A=SQRT(-LOG(RF(0)))
      B=6.283185308*RF(0)
      U=A*SIN(B)*VMP
      V=A*COS(B)*VMP
      RETURN
      END
c Implementation of CLL kernel added by SH
      SUBROUTINE CLL(U,V,W,VMP)
      COMMON /INNERBOUN/ ALFNORM,ALFTANG
*     
      U=U/VMP
      V=V/VMP
      W=W/VMP
      PI=3.141592654
      RN=SQRT(-ALFNORM*LOG(RF(0)))
      RT=SQRT(-ALFTANG*LOG(RF(0)))
      UM=SQRT(1-ALFNORM)*ABS(U)
      VM=SQRT(1-ALFTANG)*V
*      WM=SQRT(1-ALFTANG)*ABS(W)
      TN=2.0*PI*RF(0)
      TT=2.0*PI*RF(0)
      U=(SQRT(RN**2+UM**2+2.*UM*RN*COS(TN)))*VMP
      V=(VM+RT*COS(TT))*VMP
      W=(RT*SIN(TT))*VMP
      RETURN
      END
*
*   GAM.FOR
*
      FUNCTION GAM(X)
*
*--calculates the Gamma function of X.
*
      A=1.
      Y=X
      IF (Y.LT.1.) THEN
        A=A/Y
      ELSE
50      Y=Y-1
        IF (Y.GE.1.) THEN
          A=A*Y
          GO TO 50
        END IF
      END IF
      GAM=A*(1.-0.5748646*Y+0.9512363*Y**2-0.6998588*Y**3+
     &    0.4245549*Y**4-0.1010678*Y**5)
      RETURN
      END
*   COLLMR.FOR
*
      SUBROUTINE COLLMR
*
*--calculates collisions appropriate to DTM in a gas mixture
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
      DOUBLE PRECISION CSR(MNC,MNSP)
*
      COMMON /MOLS  / NM,PP(MNM),PV(3,MNM),IPL(MNM),IPS(MNM),IR(MNM)
      COMMON /MOLSR / PR(MNM)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /SAMPR / CSR
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /CONST / PI,SPI,BOLTZ
      COMMON /ELAST / VRC(3),VRR,VR,L,M,LS,MS,CVR,MM,NN,N
      COMMON /FREQ / XRELV(MNC),NSAMP(MNC),COLRATE(MNC),RELV

      COMMON /STRIKE/ FLAG(MNM),INCI(MNM),SCATTER(MNM),TRACK(MNM),
     &			STRKPOS(MNM),SCATPOS(MNM)
      REAL MFP(MNM),NUMMFP(MNM)  
      COMMON /MFPTEST/ MFP,NUMMFP
      COMMON /MOAR/ NFLAG(MNM),RLV(MNM)
      DOUBLE PRECISION NUMCOL(NPT/10,MNC)
      DOUBLE PRECISION TESTMFP(MNM),TEST(MNM)
      
*
*--VRC(3) are the pre-collision components of the relative velocity
*
      DO 100 N=1,MNC
*--consider collisions in cell N
c	IF(MOD(NPR,100).EQ.0.0) THEN
c       		NSAMP(N)=0.
cs	ENDIF
        XRELV(N)=((CG(1,N)+CG(2,N))/2)-3.E-8
        DO 50 NN=1,MNSG
          DO 20 MM=1,MNSG
            SN=0.
            DO 10 K=1,MNSP
              IF (ISP(K).EQ.MM) SN=SN+CS(1,N,K)
10          CONTINUE
            IF (SN.GT.1.) THEN
              AVN=SN/FLOAT(NSMP)
            ELSE
              AVN=IC(2,N,MM)
            END IF
*--AVN is the average number of group MM molecules in the cell
            ASEL=0.5*IC(2,N,NN)*AVN*FNUM*CCG(1,N,NN,MM)*DTM/CC(N)
     &           +CCG(2,N,NN,MM)
*--ASEL is the number of pairs to be selected, see eqn (11.5)
            NSEL=ASEL
            CCG(2,N,NN,MM)=ASEL-NSEL
            IF (NSEL.GT.0) THEN
              IF (((NN.NE.MM).AND.(IC(2,N,NN).LT.1.OR.IC(2,N,MM).LT.1))
     &            .OR.((NN.EQ.MM).AND.(IC(2,N,NN).LT.2))) THEN
                CCG(2,N,NN,MM)=CCG(2,N,NN,MM)+NSEL
*--if there are insufficient molecules to calculate collisions,
*--the number NSEL is added to the remainer CCG(2,N,NN,MM)
              ELSE
                CVM=CCG(1,N,NN,MM)
                SELT=SELT+NSEL
                DO 12 ISEL=1,NSEL
*
                  CALL SELECT
     
                  IF (CVR.GT.CVM) CVM=CVR
*--if necessary, the maximum product in CVM is upgraded
                  IF (RF(0).LT.CVR/CCG(1,N,NN,MM)) THEN
*--the collision is accepted with the probability of eqn (11.6)
                    NCOL=NCOL+1
c                    IF (NPR.GT.10000) THEN
                     NSAMP(N)=NSAMP(N)+1
                    SEPT=SEPT+ABS(PP(L)-PP(M))
                    COL(LS,MS)=COL(LS,MS)+1.D00
                    COL(MS,LS)=COL(MS,LS)+1.D00
		    TRACK(L)=PP(L)
                    TRACK(M)=PP(M)
                    MFP(L)=MFP(L)+PP(L)
		    NUMMFP(L)=NUMMFP(L)+1.0
                    MFP(M)=MFP(M)+PP(M)
		    NUMMFP(M)=NUMMFP(M)+1.0
		    IF (NFLAG(L).EQ.1) THEN
			NFLAG(L)=0
		    END IF
		    IF (NFLAG(M).EQ.1) THEN
			NFLAG(M)=0
		    END IF
		    IF (FLAG(L).EQ.1) THEN
			SCATTER(L)=ABS(PP(L)-SCATPOS(L))
			FLAG(L)=0
 			NFLAG(L)=1
		    END IF
		    IF (FLAG(M).EQ.1) THEN
			SCATTER(M)=ABS(PP(M)-SCATPOS(M))
			FLAG(M)=0
			NFLAG(M)=1
		    END IF
*
                    IF (ISPR(1,LS).GT.0.OR.ISPR(1,MS).GT.0) CALL INELR
*--bypass rotational redistribution if both molecules are monatomic
*
                    CALL ELASTIC
*
                  END IF
12              CONTINUE
                CCG(1,N,NN,MM)=CVM
                
              END IF
            END IF
20        CONTINUE
50      CONTINUE

c	COLRATE(N)=NSAMP(N)/TIME
	IF(MOD(NPR,10).EQ.0.0) THEN
       		NUMCOL(NPR/10,N)=NSAMP(N)/(NIS*NSP*DTM*10.)
	ENDIF
	IF(NPR.EQ.NPT) THEN
		DO 13 NNN=1,NPT/10
               		COLRATE(N)=COLRATE(N)+NUMCOL(NNN,N)
13		CONTINUE
	COLRATE(N)=COLRATE(N)/(NPT/10)
	ENDIF
	IF(MOD(NPR,10).EQ.0.0) THEN
       		NSAMP(N)=0.
	ENDIF
100   CONTINUE     
      RETURN
      END
*   INELR.FOR
*
      SUBROUTINE INELR
*
*--adjustment of rotational energy in a collision
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      COMMON /MOLSR / PR(MNM)
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /ELAST / VRC(3),VRR,VR,L,M,LS,MS,CVR,MM,NN,N
*
      DIMENSION IR(2)
*--IR is the indicator for the rotational redistribution
      ETI=0.5*SPM(5,LS,MS)*VRR
*--ETI is the initial translational energy
      ECI=0.
*--ECI is the initial energy in the active rotational modes
      ECF=0.
*--ECF is the final energy in these modes
      ECC=ETI
*--ECC is the energy to be divided
      XIB=2.5-SPM(3,LS,MS)
*--XIB is th number of modes in the redistribution
      IRT=0
*--IRT is 0,1 if no,any redistribution is made
      DO 100 NSP=1,2
*--consider the molecules in turn
        IF (NSP.EQ.1) THEN
          K=L
          KS=LS
          JS=MS
        ELSE
          K=M
          KS=MS
          JS=LS
        END IF
        IR(NSP)=0
        IF (ISPR(1,KS).GT.0) THEN
          IF (ISPR(2,KS).EQ.0) THEN
            ATK=1./SPR(1,KS,JS)
          ELSE
            ATK=1./(SPR(1,KS,JS)+SPR(2,KS,JS)*CT(N)+SPR(3,KS,JS)*CT(N)
     &          **2)
          END IF
*--ATK is the probability that rotation is redistributed to molecule L
          IF (ATK.GT.RF(0)) THEN
            IRT=1
            IR(NSP)=1
            ECC=ECC+PR(K)
            ECI=ECI+PR(K)
            XIB=XIB+0.5*ISPR(1,KS)
          END IF
        END IF
100   CONTINUE
*--apply the general Larsen-Borgnakke distribution function
      IF (IRT.EQ.1) THEN
        DO 150 NSP=1,2
          IF (IR(NSP).EQ.1) THEN
            IF (NSP.EQ.1) THEN
              K=L
              KS=LS
            ELSE
              K=M
              KS=MS
            END IF
            XIB=XIB-0.5*ISPR(1,KS)
*--the current molecule is removed from the total modes
            IF (ISPR(1,KS).EQ.2) THEN
              ERM=1.-RF(0)**(1./XIB)
            ELSE
              XIA=0.5*ISPR(1,KS)
              CALL LBS(XIA-1.,XIB-1.,ERM)
            END IF
            PR(K)=ERM*ECC
            ECC=ECC-PR(K)
*--the available energy is reduced accordingly
            ECF=ECF+PR(K)
          END IF
150     CONTINUE
        ETF=ETI+ECI-ECF
*--ETF  is the post-collision translational energy
*--adjust VR and, for the VSS model, VRC for the change in energy
        A=SQRT(2.*ETF/SPM(5,LS,MS))
        IF (ABS(SPM(4,LS,MS)-1.).LT.1.E-3) THEN
          VR=A
        ELSE
          DO 160 K=1,3
            VRC(K)=VRC(K)*A/VR
160       CONTINUE
          VR=A
        END IF
      END IF
      RETURN
      END
*   LBS.FOR
      SUBROUTINE LBS(XMA,XMB,ERM)
*--selects a Larsen-Borgnakke energy ratio using eqn (11.9)
100   ERM=RF(0)
      IF (XMA.LT.1.E-6.OR.XMB.LT.1.E-6) THEN
        IF (XMA.LT.1.E-6.AND.XMB.LT.1.E-6) RETURN
        IF (XMA.LT.1.E-6) P=(1.-ERM)**XMB
        IF (XMB.LT.1.E-6) P=(1.-ERM)**XMA
      ELSE
        P=(((XMA+XMB)*ERM/XMA)**XMA)*(((XMA+XMB)*(1.-ERM)/XMB)**XMB)
      END IF
      IF (P.LT.RF(0)) GO TO 100
      RETURN
      END
*   RF.FOR
*
      FUNCTION RF(IDUM)
*--generates a uniformly distributed random fraction between 0 and 1
*----IDUM will generally be 0, but negative values may be used to
*------re-initialize the seed
      SAVE MA,INEXT,INEXTP
      PARAMETER (MBIG=1000000000,MSEED=161803398,MZ=0,FAC=1.E-9)
      DIMENSION MA(55)
      DATA IFF/0/
      IF (IDUM.LT.0.OR.IFF.EQ.0) THEN
        IFF=1
        MJ=MSEED-IABS(IDUM)
        MJ=MOD(MJ,MBIG)
        MA(55)=MJ
        MK=1
        DO 50 I=1,54
          II=MOD(21*I,55)
          MA(II)=MK
          MK=MJ-MK
          IF (MK.LT.MZ) MK=MK+MBIG
          MJ=MA(II)
50      CONTINUE
        DO 100 K=1,4
          DO 60 I=1,55
            MA(I)=MA(I)-MA(1+MOD(I+30,55))
            IF (MA(I).LT.MZ) MA(I)=MA(I)+MBIG
60        CONTINUE
100     CONTINUE
        INEXT=0
        INEXTP=31
      END IF
200   INEXT=INEXT+1
      IF (INEXT.EQ.56) INEXT=1
      INEXTP=INEXTP+1
      IF (INEXTP.EQ.56) INEXTP=1
      MJ=MA(INEXT)-MA(INEXTP)
      IF (MJ.LT.MZ) MJ=MJ+MBIG
      MA(INEXT)=MJ
      RF=MJ*FAC
      IF (RF.GT.1.E-8.AND.RF.LT.0.99999999) RETURN
      GO TO 200
      END
*
      FUNCTION DELTA(T)
      DOUBLE PRECISION T,B,M,PI,BOLTZ,FTMP,XB
*      
      M=6.6E-26
      PI=3.141592654
      BOLTZ=1.380622E-23
      FTMP=300.
*      FND=9.66E24
      XB=2.045E-7
      B=EXP(0.56758528*LOG(T)-100.15251/T+2573.6598/(T**2)+2.237407)*
     &    1.0E-4

       DELTA=-4.*PI*XB*(-3.91709E-9/3.*T*T*T
     &          +3.83377E-5/2.*T**2+0.00827718*T-(-3.91709E-9/
     &         3.*FTMP*FTMP*FTMP+3.83377E-5/2.*FTMP**2+0.00827718*FTMP))
*
       WRITE (*,99011) DELTA,B
99011  FORMAT ('DELTA',E12.4,'  THERMALCOND',E12.4)
      RETURN
      END
*
      SUBROUTINE LAWKELTON(LK)
c added by SH
      PARAMETER (MNM=600000,MNC=20000,MNSC=4000,MNSP=1,MNSG=1)
      COMMON /CONST / PI,SPI,BOLTZ
      REAL NU_H(1000000),SPD(1000000)
      COMMON /OUTERBOUN/ HCOND0,QAVE,NU_H,Q_CON,SPD
      COMMON /LAWKEL/ SLOPE(100000)

      DOUBLE PRECISION SUM1,SUM2,SUM3,SUM4,ANOT
      DOUBLE PRECISION AONE(100000)
*
      SUM1=0.0
      SUM2=0.0
      SUM3=0.0
      SUM4=0.0
*      
c Linear Interpolation
      J=100*LK-100
      DO JJ=J,J+100
         SUM1=SUM1+NU_H(JJ)*JJ
         SUM2=SUM2+JJ
         SUM3=SUM3+JJ*JJ
         SUM4=SUM4+NU_H(JJ)
      END DO
*
      AONE(LK)=(100.*SUM1-(SUM2*SUM4))/(100.*SUM3-(SUM2)**2)
      SLOPE(LK)=AONE(LK)
      ANOT=(SUM4/100.-AONE(LK)*SUM2/100.)
*
c      OPEN(4,FILE='AONE_9E24_1e7.txt',FORM='FORMATTED')
c	DO 7 I=1,LK
c	   WRITE(4,997) I, AONE(I)
c7      CONTINUE
c 997   FORMAT (' ',I16,1P,E12.4)
c      CLOSE(4)
*
c      IF (ABS(AONE(LK)).LT.1.E-9)STOP 
*      
      RETURN
      END
*   DATA1.FOR
*
      SUBROUTINE DATA1
*
*--defines the data for a particular run of DSMC1.FOR.
*
      PARAMETER (MNM=600000,MNC=2000,MNSC=40000,MNSP=1,MNSG=1)
*
      DOUBLE PRECISION COL(MNSP,MNSP),MOVT,NCOL,SELT,SEPT,CS(7,MNC,MNSP)
*
      COMMON /GAS   / SP(5,MNSP),SPM(6,MNSP,MNSP),ISP(MNSP)
      COMMON /GASR  / SPR(3,MNSP,MNSP),ISPR(3,MNSP),CT(MNC)
      COMMON /CELLS1/ CC(MNC),CG(3,MNC),IC(2,MNC,MNSG),ISC(MNSC),
     &                CCG(2,MNC,MNSG,MNSG),ISCG(2,MNSC,MNSG),IG(2,MNSG),
     &                IFC,CWR,AP,RP
      COMMON /SAMP  / COL,NCOL,MOVT,SELT,SEPT,CS,TIME,NPR,NSMP,FND,FTMP,
     &                TIMI,FSP(MNSP),ISPD
      COMMON /COMP  / FNUM,DTM,NIS,NSP,NPS,NPT
      COMMON /GEOM1 / IFX,NSC,XB(2),IB(2),BT(2),BVY(2),BFND(2),BFTMP(2),
     &                BVFX(2),BFSP(2,MNSP),BME(2,MNSP),BMR(2,MNSP),IIS,
     &                CW,FW,GRAV

      REAL NU_H(1000000),SPD(1000000)
      COMMON /OUTERBOUN/ HCOND0,QAVE,NU_H,Q_CON,SPD
      COMMON /INNERBOUN/ ALFNORM,AFLTANG
*
      ALFNORM=0.3
      ALFTANG=0.3
c      CWR=0.01
c accomd. coeff. from Daun's MD simulations      
      QAVE=0.
      HCOND0=0.0177
*--set data (must be consistent with PARAMETER variables)
*
      IFX=2
*--it is a plane flow
      IIS=1
*--there is initially a stream with a velocity gradient
      FTMP=300.
*--FTMP is the temperature
      FND=9.66E27
*--FND is the number densty
      FSP(1)=1.
*--FSP(N) is the number fraction of species N
      FNUM=5E5	
*--FNUM  is the number of real molecules represented by a simulated mol.
      DTM=2.5E-16
*--DTM is the time step
      XB(1)=3.E-8
      XB(2)=2.E-7
*--the simulated region is from x=XB(1) to x=XB(2)
      IB(1)=3
      BT(1)=3000.
      BVY(1)=0.
*--the inner wall is stationary at a temperature of 273 K
*
      IB(2)=3
      BT(2)=300.
      BVY(2)=0.
*--the outer boundary is also at 273 K, but moves at 300 m/s
      SP(1,1)=4.15E-10
      SP(2,1)=293.
      SP(3,1)=0.81
      SP(4,1)=1.0
      SP(5,1)=6.6E-26
*--SP(1,N) is the molecular diameter of species N
*--SP(2,N) is the reference temperature
*--SP(3,N) is the viscosity-temperature index
*--SP(4,N) is the reciprocal of the VSS scattering parameter
*--SP(5,N) is the molecular mass of species N
      ISPR(1,1)=0
      SPR(1,1,1)=0.
      ISPR(2,1)=0
*--ISPR(1,N) is the number of degrees of freedom of species N
*--SPR(1,N,K) is the constant in the polynomial for the rotational
*--relaxation collision number of species N in collision with species K
*--ISPR(2,N) is 0,1 for constant, polynomial for collision number
      NIS=4
*--NIS is the number of time steps between samples
      NSP=20
*--NSP is the number of samples between restart and output file updates
      NPS=500
*--NPS is the number of updates to reach assumed steady flow
      NPT=200000
*--NPT is the number of file updates to STOP
*
      RETURN
      END
