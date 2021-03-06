! REFERENCE STATE MODULE
! Contains routines for initializing the reference state structure
! Reference state structure contains all information related to background
! stratification.  It DOES NOT contain transport variable (e.g. nu, kappa) information



Module ReferenceState
    Use ProblemSize
    Use Controls
    Use Math_Constants
    Use Math_Utility
    Use General_MPI, Only : BCAST2D
    Implicit None
    Type ReferenceInfo
        Real*8, Allocatable :: Density(:)
        Real*8, Allocatable :: dlnrho(:)
        Real*8, Allocatable :: d2lnrho(:)

        Real*8, Allocatable :: Pressure(:)

        Real*8, Allocatable :: Temperature(:)
        Real*8, Allocatable :: dlnT(:)

        Real*8, Allocatable :: Entropy(:)
        Real*8, Allocatable :: dsdr(:)

        Real*8, Allocatable :: Gravity(:)

        Real*8 :: gamma
        Real*8, Allocatable :: heating(:)

        Real*8 :: Coriolis_Coeff ! Multiplies z_hat x u in momentum eq.
        Real*8 :: Lorentz_Coeff ! Multiplies (Del X B) X B in momentum eq.
        Real*8, Allocatable :: Buoyancy_Coeff(:)    ! Multiplies {S,T} in momentum eq. ..typically = gravity/cp
        Real*8, Allocatable :: dpdr_w_term(:)  ! multiplies d_by_dr{P/rho} in momentum eq.
        Real*8, Allocatable :: pressure_dwdr_term(:) !multiplies l(l+1)/r^2 (P/rho) in Div dot momentum eq.
        
        ! The following two terms are used to compute the ohmic and viscous heating
        Real*8, Allocatable :: ohmic_amp(:) !multiplied by {eta(r),H(r)}J^2 in dSdt eq.
        Real*8, Allocatable :: viscous_amp(:) !multiplied by {nu(r),N(r)}{e_ij terms) in dSdt eq.

        Real*8 :: script_N_Top ! If a nondimensional reference state is employed,
        Real*8 :: script_K_Top ! these are used in lieu of nu_top from the input file.
        Real*8 :: script_H_Top ! {N:nu, K:kappa, H:eta} 

    End Type ReferenceInfo

    Real*8 :: rayleigh_constants(1:7)
    Real*8, Allocatable :: rayleigh_functions(:,:)

    Real*8, Allocatable :: s_conductive(:)

    Integer :: reference_type =1
    Integer :: heating_type = 0 ! 0 means no reference heating.  > 0 selects optional reference heating
    Integer :: cooling_type = 0 ! 0 means no reference cooling.  > 0 will ADD to any exisiting reference heating
    Real*8  :: Luminosity = 0.0d0 ! specifies the integral of the heating function
    Real*8  :: Heating_Integral = 0.0d0  !same as luminosity (for non-star watchers)
    Real*8  :: Heating_EPS = 1.0D-12  !Small number to test whether luminosity specified
    Logical :: adjust_reference_heating = .false.  ! Flag used to decide if luminosity determined via boundary conditions
    Real*8  :: heating_factor = 0.0d0, heating_r0 = 0.0d0  ! scaling and shifting factors for
    Real*8  :: cooling_factor = 0.0d0, cooling_r0 = 0.0d0  ! heating and cooling
    Type(ReferenceInfo) :: ref

    Real*8 :: pressure_specific_heat  = 0.0d0 ! CP (not CV)
    Real*8 :: poly_n = 0.0d0    !polytropic index
    Real*8 :: poly_Nrho = 0.0d0
    Real*8 :: poly_mass = 0.0d0
    Real*8 :: poly_rho_i =0.0d0
    Real*8 :: Gravitational_Constant = 6.67d-8
    Real*8 :: Angular_Velocity = 1.0d0

    !/////////////////////////////////////////////////////////////////////////////////////
    ! Nondimensional Parameters
    Real*8 :: Rayleigh_Number         = 1.0d0
    Real*8 :: Ekman_Number            = 1.0d0
    Real*8 :: Prandtl_Number          = 1.0d0
    Real*8 :: Magnetic_Prandtl_Number = 1.0d0
    Real*8 :: gravity_power           = 0.0d0
    Real*8 :: Dissipation_Number      = 0.0d0
    Real*8 :: Modified_Rayleigh_Number = 0.0d0
    Logical :: Dimensional_Reference = .false.  ! Changed depending on reference state specified
    Character*120 :: custom_reference_file ='nothing'
    Integer :: custom_reference_type = 1

    ! These last two flags are deprecated.  They are retained for now to prevent crashes due to improper input
    Logical :: Dimensional = .false., NonDimensional_Anelastic = .false. 
    Namelist /Reference_Namelist/ reference_type,poly_n, poly_Nrho, poly_mass,poly_rho_i, &
            & pressure_specific_heat, heating_type, luminosity, Angular_Velocity, &
            & Rayleigh_Number, Ekman_Number, Prandtl_Number, Magnetic_Prandtl_Number, &
            & gravity_power, heating_factor, heating_r0, custom_reference_file, &
            & custom_reference_type, cooling_type, cooling_r0, cooling_factor, &
            & Dissipation_Number, Modified_Rayleigh_Number, Heating_Integral, &
            & Dimensional, NonDimensional_Anelastic
Contains

    Subroutine Initialize_Reference()
        Implicit None
        If (my_rank .eq. 0) Then
            Call stdout%print(" -- Initalizing Reference State...")
            Call stdout%print(" ---- Specified parameters:")
        Endif
        Call Allocate_Reference_State()
        If (reference_type .eq. 1) Then
            Call Constant_Reference()
        Endif

        If (reference_type .eq. 2) Then
            Call Polytropic_Reference()

        Endif

        If (reference_type .eq. 3) Then
            Call Polytropic_ReferenceND()
        Endif

        If (reference_type .eq. 4) Then
            If (custom_reference_type .eq. 1) Then
                Call Get_Custom_Reference()
            Endif
        Endif
        If (my_rank .eq. 0) Then
            Call stdout%print(" -- Reference State initialized.")
            Call stdout%print(" ")
        Endif

        Call Write_Reference()
    End Subroutine Initialize_Reference

    Subroutine Allocate_Reference_State
        Implicit None
        Allocate(ref%density(1:N_R))
        Allocate(ref%pressure(1:N_R))
        Allocate(ref%temperature(1:N_R))
        Allocate(ref%entropy(1:N_R))
        Allocate(ref%gravity(1:N_R))
        Allocate(ref%dlnrho(1:N_R))
        Allocate(ref%d2lnrho(1:N_R))
        Allocate(ref%dlnt(1:N_R))
        Allocate(ref%dsdr(1:N_R))
        Allocate(ref%Buoyancy_Coeff(1:N_R))
        Allocate(ref%dpdr_w_term(1:N_R))
        Allocate(ref%pressure_dwdr_term(1:N_R))
        Allocate(ref%ohmic_amp(1:N_R))
        Allocate(ref%viscous_amp(1:N_R))
    End Subroutine Allocate_Reference_State
    Subroutine Constant_Reference()
        Implicit None
        Integer :: i
        Real*8 :: r_outer, r_inner, prefactor, amp, pscaling
        Character*6  :: istr
		Character*12 :: dstring
    	Character*8 :: dofmt = '(ES12.5)'
        Dimensional_Reference = .false.
        viscous_heating = .false.  ! Turn this off for Boussinesq runs
        If (my_rank .eq. 0) Then
            Call stdout%print(" ---- Reference type           : "//trim(" Boussinesq (Non-dimensional)"))
            Write(dstring,dofmt)Rayleigh_Number
            Call stdout%print(" ---- Rayleigh Number          : "//trim(dstring))
            Write(dstring,dofmt)Ekman_Number
            Call stdout%print(" ---- Ekman Number             : "//trim(dstring))
            Write(dstring,dofmt)Prandtl_Number
            Call stdout%print(" ---- Prandtl Number           : "//trim(dstring))
            If (magnetism) Then
                Write(dstring,dofmt)Magnetic_Prandtl_Number
                Call stdout%print(" ---- Magnetic Prandtl Number  : "//trim(dstring))
            Endif
        Endif

        ref%density      = 1.0d0
        ref%dlnrho       = 0.0d0
        ref%d2lnrho      = 0.0d0
        ref%pressure     = 1.0d0
        ref%temperature  = 1.0d0
        ref%dlnT         = 0.0d0
        ref%dsdr         = 0.0d0
        ref%pressure     = 1.0d0
        ref%gravity      = 0.0d0 ! Not used with constant reference right now

        amp = Rayleigh_Number/Prandtl_Number

        Do i = 1, N_R
            ref%Buoyancy_Coeff(i) = amp*(radius(i)/radius(1))**gravity_power
        Enddo

        pressure_specific_heat = 1.0d0
        Call initialize_reference_heating()
        If (heating_type .eq. 0) Then
            !Otherwise, s_conductive will be calculated in initial_conditions
            Allocate(s_conductive(1:N_R))
            r_outer = radius(1)
            r_inner = radius(N_R)
            prefactor = r_outer*r_inner/(r_inner-r_outer)
            Do i = 1, N_R
                s_conductive(i) = prefactor*(1.0d0/r_outer-1.0d0/radius(i))
            Enddo
        Endif

        If (.not. rotation) Then
            pscaling = 1.0d0
        Else
            pscaling = 1.0d0/Ekman_Number
        Endif

        !Define the various equation coefficients
        ref%dpdr_w_term(:)        =  ref%density*pscaling
        ref%pressure_dwdr_term(:) = -1.0d0*ref%density*pscaling
        ref%Coriolis_Coeff        =  2.0d0/Ekman_Number          


        ref%script_N_top       = 1.0d0
        ref%script_K_top       = 1.0d0/Prandtl_Number
        ref%viscous_amp(1:N_R) = 2.0d0

        If (magnetism) Then
            ref%Lorentz_Coeff    = 1.0d0/(Magnetic_Prandtl_Number*Ekman_Number)
            ref%script_H_Top     = 1.0d0/Magnetic_Prandtl_Number
            ref%ohmic_amp(1:N_R) = ref%lorentz_coeff 
        Else
            ref%Lorentz_Coeff    = 0.0d0
            ref%script_H_Top     = 0.0d0
            ref%ohmic_amp(1:N_R) = 0.0d0
        Endif            
    
    End Subroutine Constant_Reference
    Subroutine Polytropic_ReferenceND()
        Implicit None
        Real*8 :: dtmp, otmp
        Real*8, Allocatable :: dtmparr(:)
        Character*6  :: istr
		Character*12 :: dstring
    	Character*8 :: dofmt = '(ES12.5)'
        Dimensional_Reference = .false.
        If (my_rank .eq. 0) Then
            Call stdout%print(" ---- Reference type           : "//trim(" Polytrope (Non-dimensional)"))
            Write(dstring,dofmt)Modified_Rayleigh_Number
            Call stdout%print(" ---- Modified Rayleigh Number : "//trim(dstring))
            Write(dstring,dofmt)Ekman_Number
            Call stdout%print(" ---- Ekman Number             : "//trim(dstring))
            Write(dstring,dofmt)Prandtl_Number
            Call stdout%print(" ---- Prandtl Number           : "//trim(dstring))
            If (magnetism) Then
                Write(dstring,dofmt)Magnetic_Prandtl_Number
                Call stdout%print(" ---- Magnetic Prandtl Number  : "//trim(dstring))
            Endif
            Write(dstring,dofmt)poly_n
            Call stdout%print(" ---- Polytropic Index         : "//trim(dstring))
            Write(dstring,dofmt)poly_nrho
            Call stdout%print(" ---- Density Scaleheights     : "//trim(dstring))
        Endif

        If (aspect_ratio .lt. 0) Then
            aspect_ratio = rmax/rmin
        Endif
        Allocate(dtmparr(1:N_R))
        dtmparr(:) = 0.0d0

        Dissipation_Number = aspect_ratio*(exp(poly_Nrho/poly_n)-1.0D0)
        dtmp = 1.0D0/(1.0D0-aspect_ratio)
        ref%temperature(:) = dtmp*Dissipation_Number*(dtmp*One_Over_R(:)-1.0D0)+1.0D0
        ref%density(:) = ref%temperature(:)**poly_n
        ref%gravity = (rmax**2)*OneOverRSquared(:)
        ref%Buoyancy_Coeff = ref%gravity*Modified_Rayleigh_Number*ref%density

        !Compute the background temperature gradient : dTdr = -Dg,  d2Tdr2 = 2*D*g/r (for g ~1/r^2)
        dtmparr = -Dissipation_Number*ref%gravity
        !Now, the logarithmic derivative of temperature
        ref%dlnt = dtmparr/ref%temperature
        
        !And then logarithmic derivative of rho : dlnrho = n dlnT
        ref%dlnrho = poly_n*ref%dlnt

        !Now, the second logarithmic derivative of rho :  d2lnrho = (n/T)*d2Tdr2 - n*(dlnT^2)
        ref%d2lnrho = -poly_n*(ref%dlnT**2)  

        dtmparr = (poly_n/ref%temperature)*(2.0d0*Dissipation_Number*ref%gravity/radius) ! (n/T)*d2Tdr2
        ref%d2lnrho = ref%d2lnrho+dtmparr

        DeAllocate(dtmparr)

        ref%entropy(:) = 0.0d0  ! Might need to adjust this later
        ref%dsdr(:) = 0.0d0
        ref%pressure(:) = ref%density*ref%temperature !  this is never used, might be missing a prefactor
        Call Initialize_Reference_Heating()
        

        ref%Coriolis_Coeff = 2.0d0
        ref%dpdr_w_term(:) = ref%density
        ref%pressure_dwdr_term(:) = -1.0d0*ref%density

        ref%script_N_top   = Ekman_Number
        ref%script_K_top   = Ekman_Number/Prandtl_Number
        ref%viscous_amp(1:N_R) = 2.0d0/ref%temperature(1:N_R)* &
                                 & Dissipation_Number/Modified_Rayleigh_Number

        If (magnetism) Then
            !ref%Lorentz_Coeff    = Prandtl_Number/(Magnetic_Prandtl_Number*Ekman_Number) <-- Original version - incorrect
            ref%Lorentz_Coeff    = Ekman_Number/(Magnetic_Prandtl_Number) ! <--- new version (jan 22, 2018)
            ref%script_H_top     = Ekman_Number/Magnetic_Prandtl_Number

            otmp = (Dissipation_Number*Ekman_Number**2)/(Modified_Rayleigh_Number*Magnetic_Prandtl_Number**2)
            ref%ohmic_amp(1:N_R) = otmp/ref%density(1:N_R)/ref%temperature(1:N_R)
        Else
            ref%Lorentz_Coeff    = 0.0d0
            ref%script_H_Top     = 0.0d0
            ref%ohmic_amp(1:N_R) = 0.0d0
        Endif


    End Subroutine Polytropic_ReferenceND

    Subroutine Polytropic_Reference()
        Real*8 :: zeta_0,  c0, c1, d
        Real*8 :: rho_c, P_c, T_c,denom
        Real*8 :: beta, Gas_Constant
        Real*8, Allocatable :: zeta(:)
        Real*8 :: One, ee
        Real*8 :: InnerRadius, OuterRadius
        Integer :: r
        Character*6  :: istr
		Character*12 :: dstring
    	Character*8 :: dofmt = '(ES12.5)'
        If (my_rank .eq. 0) Then
            Call stdout%print(" ---- Reference type                : "//trim(" Polytrope (Dimensional)"))
            Write(dstring,dofmt)Angular_Velocity
            Call stdout%print(" ---- Angular Velocity (rad/s)      : "//trim(dstring))
            Write(dstring,dofmt)poly_rho_i
            Call stdout%print(" ---- Inner-Radius Density (g/cm^3) : "//trim(dstring))
            Write(dstring,dofmt)poly_mass
            Call stdout%print(" ---- Interior Mass  (g)            : "//trim(dstring))
            Write(dstring,dofmt)poly_n
            Call stdout%print(" ---- Polytropic Index              : "//trim(dstring))
            Write(dstring,dofmt)poly_nrho
            Call stdout%print(" ---- Density Scaleheights          : "//trim(dstring))
            Write(dstring,dofmt)pressure_specific_heat
            Call stdout%print(" ---- CP (erg g^-1 cm^-3 K^-1)      : "//trim(dstring))
        Endif

        Dimensional_Reference = .true. ! This is actually the default

        ! Adiabatic, Polytropic Reference State (see, e.g., Jones et al. 2011)
        ! The following parameters are read from the input file.
        ! poly_n
        ! poly_Nrho
        ! poly_mass
        ! poly_rho_i

        ! Note that cp must also be specified.
        InnerRadius = Radius(N_r)
        OuterRadius = Radius(1)
        

        One = 1.0d0
        !-----------------------------------------------------------
        beta = InnerRadius/OuterRadius

        denom = beta * exp(poly_Nrho / poly_n) + 1.d0
        zeta_0 = (beta+1.d0)/denom

        c0 = (2.d0 * zeta_0 - beta - 1.d0) / (1.d0 - beta)

        denom = (1.d0 - beta)**2
        c1 = (1.d0+beta)*(1.d0-zeta_0)/denom

        !-----------------------------------------------------------
        ! allocate and define zeta
        ! also rho_c, T_c, P_c

        Allocate(zeta(N_R))

        d = OuterRadius - InnerRadius    

        zeta = c0 + c1 * d / Radius

        rho_c = poly_rho_i / zeta(N_R)**poly_n

        denom = (poly_n+1.d0) * d * c1
        P_c = Gravitational_Constant * poly_mass * rho_c / denom

        T_c = (poly_n+1.d0) * P_c / (Pressure_Specific_Heat * rho_c)

        !-----------------------------------------------------------
        ! Initialize reference structure 
        ref%gamma = (poly_n+1.0D0)/(poly_n)

        If (STABLE_flag) Then

           ref%gamma = 5.d0/3.d0

        Endif


        Gas_Constant = (ref%Gamma-one)*Pressure_Specific_Heat/ref%Gamma

        Ref%Gravity = Gravitational_Constant * poly_mass / Radius**2

        Ref%Density = rho_c * zeta**poly_n

        Ref%dlnrho = - poly_n * c1 * d / (zeta * Radius**2)
        Ref%d2lnrho = - Ref%dlnrho*(2.0d0/Radius-c1*d/zeta/Radius**2)

        Ref%Temperature = T_c * zeta
        Ref%dlnT = -(c1*d/Radius**2)/zeta

        Ref%Pressure = P_c * zeta**(poly_n+1)

        denom = P_c**(1.d0/ref%gamma)
        Ref%Entropy = Pressure_Specific_Heat * log(denom/rho_c)

        Ref%dsdr = 0.d0

        Ref%Buoyancy_Coeff = ref%gravity/Pressure_Specific_Heat*ref%density

        !We initialize s_conductive (modulo delta_s, specified by the boundary conditions)
        !If (heating_type .eq. 0) Then
        !    Allocate(s_conductive(1:N_R))
        !    s_conductive(:) = 0.0d0
        !    ee = -1.d0*poly_n
        !    denom = zeta(1)**ee - zeta(N_R)**ee
        !    Do r = 1, N_R
        !      s_conductive(r) = (zeta(1)**ee - zeta(r)**ee) / denom
        !    Enddo
        !Endif

        Deallocate(zeta)

        Call Initialize_Reference_Heating()

        ref%Coriolis_Coeff        = 2.0d0*Angular_velocity
        ref%dpdr_w_term(:)        = ref%density
        ref%pressure_dwdr_term(:) = -1.0d0*ref%density
        ref%viscous_amp(1:N_R)    = 2.0d0/ref%temperature(1:N_R)
        If (magnetism) Then
            ref%Lorentz_Coeff = 1.0d0/four_pi
            ref%ohmic_amp(1:N_R) = ref%lorentz_coeff/ref%density(1:N_R)/ref%temperature(1:N_R)
        Else
            ref%Lorentz_Coeff = 0.0d0
            ref%ohmic_amp(1:N_R) = 0.0d0
        Endif
    End Subroutine Polytropic_Reference


    Subroutine Initialize_Reference_Heating()
        Implicit None
        ! This is where a volumetric heating function Phi(r) is computed
        ! This function appears in the entropy equation as
        ! dSdt = Phi(r)
        ! Phi(r) may represent internal heating of any type.  For stars, this heating would be
        ! associated with temperature diffusion of the reference state and/or nuclear burning.
        Character*12 :: dstring
        Character*8 :: dofmt = '(ES12.5)'

        If ( (heating_type .gt. 0) .or. (cooling_type .gt. 0) )Then
            If (.not. Allocated(ref%heating)) Allocate(ref%heating(1:N_R))
            ref%heating(:) = 0.0d0
        Endif

        If (heating_type .eq. 1) Then
            Call Constant_Entropy_Heating()
            If (my_rank .eq. 0) Then
                Call stdout%print(" ---- Heating type             : constant entropy")
            end if
        Endif

        If (heating_type .eq. 2) Then
            Call Tanh_Reference_Heating()
            If (my_rank .eq. 0) Then
                Call stdout%print(" ---- Heating type             : tanh reference")
            end if
        Endif

        If (heating_type .eq. 4) Then
            Call  Constant_Energy_Heating()
            If (my_rank .eq. 0) Then
                Call stdout%print(" ---- Heating type             : constant energy")
            end if
        Endif

        !///////////////////////////////////////////////////////////
        ! Next, compute a cooling function if desired and ADD it to 
        ! whatever's in reference heating.
        If (cooling_type .eq. 1) Then
            ! Here we generate a tanh cooling envelope for use with our drag constant
        Endif


        If (cooling_type .eq. 2) Then
            Call Tanh_Reference_Cooling()            
            If (my_rank .eq. 0) Then
                Call stdout%print(" ---- Cooling type             : tanh reference")
            end if
        Endif

        ! Heating Q_H and cooling Q_C are normalized so that:
        ! Int_volume rho T Q_H dV = 1 and Int_volume rho T Q_C dV = 1

        !If luminosity or heating_integral has been set,
        !we set the integral of ref%heating using that.

        !Otherwise, we will use the boundary thermal flux
        !To establish the integral
        If ( (heating_type .gt. 0) .or. (cooling_type .gt. 0) )Then
            adjust_reference_heating = .true.
            If (abs(Luminosity) .gt. heating_eps) Then
                adjust_reference_heating = .false.
                ref%heating = ref%heating*Luminosity
                If (my_rank .eq. 0) Then
                    Write(dstring,dofmt)Luminosity
                    Call stdout%print(" ---- Luminosity               : "//trim(dstring))
                end if
            Endif

            If (abs(Heating_Integral) .gt. heating_eps) Then
                adjust_reference_heating = .false.
                ref%heating = ref%heating*Heating_Integral
                If (my_rank .eq. 0) Then
                    Write(dstring,dofmt)Heating_Integral
                    Call stdout%print(" ---- Heating integral         : "//trim(dstring))
                end if
            Endif
        Endif

    End Subroutine Initialize_Reference_Heating

    Subroutine Constant_Energy_Heating()
        Implicit None
        ! rho T dSdt = alpha : energy deposition per unit volume is constant
        ! dSdt = alpha/rhoT : entropy deposition per unit volume is ~ 1/Pressure
        ref%heating(:) = 1.0d0/shell_volume
        ref%heating = ref%heating/(ref%density*ref%temperature)
    End Subroutine Constant_Energy_Heating

    Subroutine Constant_Entropy_Heating()
        Implicit None
        Real*8 :: integral, alpha
        Real*8, Allocatable :: temp(:)

        ! dSdt = alpha : Entropy deposition per unit volume is constant
        ! rho T dSdt = rho T alpha : Energy deposition per unit volume is ~ Pressure

        ! Luminosity is specified as an input
        ! Phi(r) is set to alpha such that 
        ! Integral_r=rinner_r=router (4*pi*alpha*rho(r)*T(r)*r^2 dr) = Luminosity
        Allocate(temp(1:N_R))

        temp = ref%density*ref%temperature
        Call Integrate_in_radius(temp,integral) !Int_rmin_rmax rho T r^2 dr
        integral = integral*4.0d0*pi  ! Int_V temp dV

        
        alpha = 1.0d0/integral



        ref%heating(:) = alpha
        DeAllocate(temp)
        !Note that in the boussinesq limit, alpha = Luminosity/Volume
    End Subroutine Constant_Entropy_Heating

    Subroutine Tanh_Reference_Heating()
        Implicit None
        Real*8 :: integral, alpha
        Real*8, Allocatable :: temp(:), x(:), temp2(:)
          Integer :: i
        Character*120 :: heating_file

        ! Luminosity is specified as an input
        ! Heating is set so that temp * 4 pi r^2 integrates to one Lsun 
        ! Integral_r=rinner_r=router (4*pi*alpha*rho(r)*T(r)*r^2 dr) = Luminosity
        Allocate(temp(1:N_R))
        Allocate(temp2(1:N_R))
        Allocate(x(1:N_R))
        x = heating_factor*(radius-heating_r0)/ (maxval(radius)-minval(radius)) 
        ! x runs from zero to 1 if heating_r0 is min(radius)
        !Call tanh_profile(x,temp)
        Do i = 1, n_r
            temp2(i) = 0.5d0*(1.0d0-tanh(x(i))*tanh(x(i)))*heating_factor/(maxval(radius)-minval(radius))
        Enddo

        !temp2 = heating_factor*(1-(temp*temp))/ (maxval(radius)-minval(radius))

        temp2 = -temp2/(4*pi*radius*radius)

        Call Integrate_in_radius(temp2,integral)

        integral = integral*4.0d0*pi
        alpha = 1.0d0/integral
        
        ref%heating(:) = alpha*temp2/(ref%density*ref%temperature)
        If (my_rank .eq. 0) Then
            heating_file = Trim(my_path)//'reference_heating'
            Open(unit=15,file=heating_file,form='unformatted', status='replace',access='stream')
            Write(15)n_r
            Write(15)(radius(i),i=1,n_r)
            Write(15)(ref%heating(i), i = 1, n_r)
            Write(15)(temp(i), i = 1, n_r)
            Write(15)(temp2(i), i = 1, n_r)
            Write(15)(ref%density(i), i = 1, n_r)
            Write(15)(ref%temperature(i), i = 1, n_r)
        Endif
          
        DeAllocate(x,temp, temp2)
    End Subroutine Tanh_Reference_Heating


    Subroutine Tanh_Reference_Cooling()
        Implicit None
        Real*8 :: integral, alpha
        Real*8, Allocatable :: temp(:), x(:), temp2(:), cool_arr(:,:)
          Integer :: i
        Character*120 :: cooling_file

        ! Luminosity is specified as an input
        ! Heating is set so that temp * 4 pi r^2 integrates to one Lsun 
        ! Integral_r=rinner_r=router (4*pi*alpha*rho(r)*T(r)*r^2 dr) = Luminosity
        Allocate(temp(1:N_R))
        Allocate(temp2(1:N_R))
        Allocate(x(1:N_R))
        x = cooling_factor*(radius-cooling_r0)/ (maxval(radius)-minval(radius)) ! x runs from zero to 1 if heating_r0 is min(radius)
        !Call tanh_profile(x,temp)
        Do i = 1, n_r
            temp2(i) = 0.5d0*(1.0d0-tanh(x(i))*tanh(x(i)))*cooling_factor/(maxval(radius)-minval(radius))
        Enddo

        !temp2 = heating_factor*(1-(temp*temp))/ (maxval(radius)-minval(radius))

        temp2 = -temp2/(4*pi*radius*radius)

        Call Integrate_in_radius(temp2,integral)

        integral = integral*4.0d0*pi
        alpha = 1.0d0/integral

        !/////////////////////
        ! The "Cooling" part comes in through the minus sign here - otherwise, this is identical to the heating function
        Do i = 1, n_r        
            ref%heating(i) = ref%heating(i)-alpha*temp2(i)/(ref%density(i)*ref%temperature(i))
        Enddo
        !temp2 = ref%heating*ref%density*ref%temperature
        !Call Integrate_in_radius(temp2,integral)
        !write(6,*)'integral:  ', integral*4.0*pi

        cooling_file = Trim(my_path)//'reference_heating'
        Allocate(cool_arr(1:n_r,1:6))
        cool_arr(:,1) = radius
        cool_arr(:,2) = ref%heating
        cool_arr(:,3) = temp
        cool_arr(:,4) = temp2
        cool_arr(:,5) = ref%density
        cool_arr(:,6) = ref%temperature

        Call Write_Profile(cool_arr,cooling_file)
        DeAllocate(cool_arr)
        DeAllocate(x,temp, temp2)
    End Subroutine Tanh_Reference_Cooling

    Subroutine Integrate_in_radius(func,int_func)
        Implicit None
        Real*8, Intent(In) :: func(1:)
        Real*8, Intent(Out) :: int_func
        Integer :: i
        Real*8 :: rcube
        !compute integrate_r=rmin_r=rmax func*r^2 dr
        rcube = (rmax**3-rmin**3)*One_Third
        int_func = 0.0d0
        Do i = 1, n_r
            int_func = int_func+func(i)*radial_integral_weights(i)
        Enddo
        int_func = int_func*rcube

    End Subroutine Integrate_in_radius


    Subroutine Write_Reference(filename)
        Implicit None
        Character*120, Optional, Intent(In) :: filename
        Character*120 :: ref_file
        Integer :: i,sig = 314
        if (present(filename)) then
            ref_file = Trim(my_path)//filename
        else
            ref_file = Trim(my_path)//'reference'
        endif

        If (my_rank .eq. 0) Then
            Open(unit=15,file=ref_file,form='unformatted', status='replace',access='stream')
            Write(15)sig
            Write(15)n_r
            Write(15)(radius(i),i=1,n_r)
            Write(15)(ref%density(i),i=1,n_r)
            Write(15)(ref%dlnrho(i),i=1,n_r)
            Write(15)(ref%d2lnrho(i),i=1,n_r)
            Write(15)(ref%pressure(i),i=1,n_r)
            Write(15)(ref%temperature(i),i=1,n_r)
            Write(15)(ref%dlnT(i),i=1,n_r)
            Write(15)(ref%dsdr(i),i=1,n_r)
            Write(15)(ref%entropy(i),i=1,n_r)            
            Write(15)(ref%gravity(i),i=1,n_r)
            Close(15)
        Endif
    End Subroutine Write_Reference

    Subroutine Write_Profile(arr,filename)
        Implicit None
        Character*120, Optional, Intent(In) :: filename
        Character*120 :: ref_file
        Integer :: i,j,nq,sig = 314, nx
        Real*8, Intent(In) :: arr(1:,1:)
        nx = size(arr,1)
        nq = size(arr,2)
        If (my_rank .eq. 0) Then
            Open(unit=15,file=filename,form='unformatted', status='replace',access='stream')
            Write(15)sig
            Write(15)nx
            Write(15)nq
            Write(15)((arr(i,j),i=1,nx),j = 1, nq)

            Close(15)
        Endif
    End Subroutine Write_Profile



    Subroutine Get_Custom_Reference()
        Implicit None
        !Real*8, Allocatable :: Rayleigh_functions(:,:)
        !Real*8 :: rayleigh_constants(1:7)
        Allocate(rayleigh_functions(1:N_R,1:10))
        ! This reference state is assumed to have been calculated on
        ! the current grid.  NO INTERPOLATION will be performed here.

        ! Put some logic here for unity functions and constants from command
        ! Read the functions
        ! Read the constants
        
        ref%density(:) = rayleigh_functions(:,1)
        ref%dlnrho(:) = rayleigh_functions(:,8)
        ref%d2lnrho(:) = rayleigh_functions(:,9)
        ref%buoyancy_coeff(:) = rayleigh_constants(2)*rayleigh_functions(:,2)
        !viscosity maps to function 3 times constant 5
        ref%temperature(:) = rayleigh_functions(:,4)
        ref%dlnT(:) = rayleigh_functions(:,10)
        !kappa maps to function 5 times constant 6
        ref%heating(:) = rayleigh_functions(:,6)/(ref%density*ref%temperature)
        !eta maps to function 7 times constant 7

        ! Next, incorporate the constants        
        ref%Coriolis_Coeff = rayleigh_constants(1)
        ref%dpdr_w_term(:) = rayleigh_constants(3)*rayleigh_functions(:,1)
        ref%pressure_dwdr_term(:)= - ref%dpdr_w_term(:)  ! Hadn't noticed this redundancy before...
        ref%viscous_amp(:) = 2.0/ref%temperature(:)
        ref%Lorentz_Coeff = rayleigh_constants(4)
        ref%ohmic_amp(:) = ref%lorentz_coeff/(ref%density(:)*ref%temperature(:))
        DeAllocate(rayleigh_functions)
    End Subroutine Get_Custom_Reference


    

    Subroutine Read_Reference(filename,ref_arr)
        Character*120, Intent(In), Optional :: filename
        Character*120 :: ref_file
        Integer :: pi_integer,nr_ref
        Integer :: nqvals =9 ! Reference state file contains nqvals quantities + radius
        Integer :: i, k
        Real*8, Allocatable :: ref_arr_old(:,:), rtmp(:), rtmp2(:)
        Real*8, Intent(InOut) :: ref_arr(:,:)
        Real*8, Allocatable :: old_radius(:)
        If (present(filename)) Then
            ref_file = Trim(my_path)//filename
        Else
            ref_file = 'reference'
        Endif
        Open(unit=15,file=ref_file,form='unformatted', status='old',access='stream')
        Read(15)pi_integer

        If (pi_integer .ne. 314) Then
            close(15)
            Open(unit=15,file=ref_file,form='unformatted', status='old', &
                 CONVERT = 'BIG_ENDIAN' , access='stream')
            Read(15)pi_integer
            If (pi_integer .ne. 314) Then
                Close(15)
                Open(unit=15,file=ref_file,form='unformatted', status='old', &
                 CONVERT = 'LITTLE_ENDIAN' , access='stream')
                Read(15)pi_integer
            Endif
        Endif
                
        If (pi_integer .eq. 314) Then 

            Read(15)nr_ref
            Allocate(ref_arr_old(1:nr_ref,1:nqvals))  !10 quantities are stored in reference state
            Allocate(old_radius(1:nr_ref))

            Write(6,*)'nr_ref is: ', nr_ref

            Read(15)(old_radius(i),i=1,nr_ref)
            Do k = 1, nqvals
                Read(15)(ref_arr_old(i,k) , i=1 , nr_ref)
            Enddo
               

            !Check to see if radius isn't reversed
            !If it is not, then reverse it
            If (old_radius(1) .lt. old_radius(nr_ref)) Then
                Write(6,*)'Reversing Radial Indices in Custom Ref File!'
                Allocate(rtmp(1:nr_ref))

                Do i = 1, nr_ref
                    old_radius(i) = rtmp(nr_ref-i+1)
                Enddo

                Do k = 1, nqvals
                    rtmp(:) = ref_arr_old(:,k)
                    Do i = 1, nr_ref
                        ref_arr_old(i,k) = rtmp(nr_ref-i+1)
                    Enddo
                Enddo

                DeAllocate(rtmp)

            Endif

            Close(15)


            If (nr_ref .ne. n_r) Then 
                !Interpolate onto the current radial grid if necessary
                !Note that the underlying assumption here is that same # of grid points
                ! means same grid - come back to this later for generality
                Allocate(rtmp2(1:n_r))
                Allocate(rtmp(1:nr_ref))
                
                Do k = 1, nqvals
 
                    rtmp(:) = ref_arr_old(:,k)
                    rtmp2(:) = 0.0d0
                    Call Spline_Interpolate(rtmp, old_radius, rtmp2, radius)
                    ref_arr(1:n_r,k) = rtmp2 
                Enddo

                DeAllocate(rtmp,rtmp2)
            Else
                ! Bit redundant here, but may want to do filtering on ref_arr array
                ref_arr(1:n_r,1:nqvals) = ref_arr_old(1:n_r,1:nqvals)

            Endif


            DeAllocate(ref_arr_old,old_radius)
        Endif
    End Subroutine Read_Reference

    



    Subroutine Read_Profile_File(filename,arr)
    Character*120, Intent(In) :: filename
        Character*120 :: ref_file, full_path
        Integer :: pi_integer,nr_ref, ncolumns
        Integer :: nqvals =9 ! Reference state file contains nqvals quantities + radius
        Integer :: i, k
        Real*8, Allocatable :: arr_old(:,:), rtmp(:), rtmp2(:)
        Real*8, Intent(InOut) :: arr(:,:)
        Real*8, Allocatable :: old_radius(:)
        full_path = Trim(my_path)//filename
        If (my_rank .eq. 0) Then
            !Only one processes actually opens the file
            !After that, the contents of the array are broadcast across columns and rows
            Open(unit=15,file=full_path,form='unformatted', status='old',access='stream')
            Read(15)pi_integer

            If (pi_integer .ne. 314) Then
                close(15)
                Open(unit=15,file=full_path,form='unformatted', status='old', &
                     CONVERT = 'BIG_ENDIAN' , access='stream')
                Read(15)pi_integer
                If (pi_integer .ne. 314) Then
                    Close(15)
                    Open(unit=15,file=full_path,form='unformatted', status='old', &
                     CONVERT = 'LITTLE_ENDIAN' , access='stream')
                    Read(15)pi_integer
                Endif
            Endif
                    
            If (pi_integer .eq. 314) Then 

                Read(15)nr_ref
                Read(15)ncolumns
                nqvals = ncolumns-1
                Allocate(arr_old(1:nr_ref,1:nqvals))  
                !10 quantities are stored in reference state

                Allocate(old_radius(1:nr_ref))

                Write(6,*)'nr_ref is: ', nr_ref

                Read(15)(old_radius(i),i=1,nr_ref)
                
                Do k = 1, nqvals
                    Read(15)(arr_old(i,k) , i=1 , nr_ref)
                Enddo
                   

                !Check to see if radius isn't reversed
                !If it is not, then reverse it
                If (old_radius(1) .lt. old_radius(nr_ref)) Then
                    Write(6,*)'Reversing Radial Indices in Custom Ref File!'
                    Allocate(rtmp(1:nr_ref))
                    rtmp(:) = old_radius(:)
                    Do i = 1, nr_ref
                        old_radius(i) = rtmp(nr_ref-i+1)
                    Enddo

                    Do k = 1, nqvals
                        rtmp(:) = arr_old(:,k)
                        Do i = 1, nr_ref
                            arr_old(i,k) = rtmp(nr_ref-i+1)
                        Enddo
                    Enddo

                    DeAllocate(rtmp)

                Endif

                Close(15)


                If (nr_ref .ne. n_r) Then 
                    !Interpolate onto the current radial grid if necessary
                    !Note that the underlying assumption here is that same # of grid points
                    ! means same grid - come back to this later for generality
                    Allocate(rtmp2(1:n_r))
                    Allocate(rtmp(1:nr_ref))
                    
                    Do k = 1, nqvals
     
                        rtmp(:) = arr_old(:,k)
                        rtmp2(:) = 0.0d0
                        Call Spline_Interpolate(rtmp, old_radius, rtmp2, radius)
                        arr(1:n_r,k) = rtmp2 
                    Enddo

                    DeAllocate(rtmp,rtmp2)
                Else
                    ! Bit redundant here, but may want to do filtering on arr array
                    arr(1:n_r,1:nqvals) = arr_old(1:n_r,1:nqvals)

                Endif


                DeAllocate(arr_old,old_radius)
            Endif
        Endif


        If (my_row_rank .eq. 0) Then
            ! Broadcast along the column
            Call BCAST2D(arr,grp = pfi%ccomm)
        Endif
        Call BCAST2D(arr,grp = pfi%rcomm)

    End Subroutine Read_Profile_File




    Subroutine Restore_Reference_Defaults
        Implicit None
        !Restore all values in this module to their default state.
        !Deallocates all allocatable module variables.
        reference_type =1
        heating_type = 0
        Luminosity =0.0d0
        heating_factor = 0.0d0
        heating_r0 = 0.0d0


        pressure_specific_heat = 0.0d0 ! CP (not CV)
        poly_n = 0.0d0
        poly_Nrho = 0.0d0
        poly_mass = 0.0d0
        poly_rho_i = 0.0d0
        Gravitational_Constant = 6.67d-8


        Angular_Velocity = 1.0d0
    
        Rayleigh_Number         = 1.0d0
        Ekman_Number            = 1.0d0
        Prandtl_Number          = 1.0d0
        Magnetic_Prandtl_Number = 1.0d0
        gravity_power           = 0.0d0
        Dimensional_Reference = .true.  
        custom_reference_file ='nothing'
        custom_reference_type = 1

        If (allocated(s_conductive)) DeAllocate(s_conductive)
        If (allocated(ref%Density)) DeAllocate(ref%density)
        If (allocated(ref%dlnrho)) DeAllocate(ref%dlnrho)
        If (allocated(ref%d2lnrho)) DeAllocate(ref%d2lnrho)
        If (allocated(ref%Pressure)) DeAllocate(ref%Pressure)
        If (allocated(ref%Temperature)) DeAllocate(ref%Temperature)
        If (allocated(ref%dlnT)) DeAllocate(ref%dlnT)
        If (allocated(ref%Entropy)) DeAllocate(ref%Entropy)
        If (allocated(ref%dsdr)) DeAllocate(ref%dsdr)
        If (allocated(ref%Gravity)) DeAllocate(ref%Gravity)
        If (allocated(ref%Buoyancy_Coeff)) DeAllocate(ref%Buoyancy_Coeff)
        If (allocated(ref%Heating)) DeAllocate(ref%Heating)

  
    End Subroutine Restore_Reference_Defaults

End Module ReferenceState
