#define DO_PSI Do t = my_theta%min, my_theta%max;	Do r = my_r%min, my_r%max ;Do k = 1, n_phi
#define DO_PSI2 Do t = my_theta%min, my_theta%max;	Do r = my_r%min, my_r%max
#define END_DO2 enddo; enddo
#define END_DO enddo; enddo; enddo
#define PSI k,r,t
#define PSI2 r,t
!////////////////////// Diagnostics KE Flux ///////////////////////
!
!       This module handles calculation of terms associated with the kinetic energy flux
!///////////////////////////////////////////////////////////////////
Module Diagnostics_KE_Flux
    Use Diagnostics_Base

Contains
    Subroutine Compute_KE_Flux(buffer)
        Implicit None
        Real*8, Intent(InOut) :: buffer(1:,my_r%min:,my_theta%min:,1:)
        Integer :: r,k, t  
        Real*8 :: htmp1, htmp2, htmp3             ! temporary variables for use if needed
        Real*8 :: one_over_rsin, ctn_over_r        ! spherical trig
        Real*8 :: Err,Ett,Epp, Ert,Erp,Etp        ! variables to store the components of the rate of strain
        Real*8 :: Lap_r, Lap_t, Lap_p            ! variables to store Laplacians
        Real*8 :: mu, dmudr                ! the dynamic viscosity and its radial derivativ
        ! First, we compute the flux of total KE in each direction
        If (compute_quantity(ke_flux_radial) .or. compute_quantity(ke_flux_theta) &
            .or. compute_quantity(ke_flux_phi)) Then

            DO_PSI
                tmp1(PSI) = buffer(PSI,vr)**2 + buffer(PSI,vtheta)**2 + buffer(PSI,vphi)**2
            END_DO
            DO_PSI
                tmp1(PSI) = tmp1(PSI)*half*ref%density(r)
            END_DO

            If (compute_quantity(ke_flux_radial)) Then
                DO_PSI
                    qty(PSI) = buffer(PSI,vr)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(ke_flux_theta)) Then
                DO_PSI
                    qty(PSI) = buffer(PSI,vtheta)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(ke_flux_phi)) Then
                DO_PSI
                    qty(PSI) = buffer(PSI,vphi)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif

        ! Flux of mean KE due to mean flow 
        If (compute_quantity(mke_mflux_radial) .or. compute_quantity(mke_mflux_theta) &
            .or. compute_quantity(mke_mflux_phi)) Then

            DO_PSI
                tmp1(PSI) = m0_values(PSI2,vr)**2 + m0_values(PSI2,vtheta)**2 + m0_values(PSI2,vphi)**2
            END_DO
            DO_PSI
                tmp1(PSI) = tmp1(PSI)*half*ref%density(r)
            END_DO

            If (compute_quantity(mke_mflux_radial)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vr)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(mke_mflux_theta)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vtheta)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(mke_mflux_phi)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vphi)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif

        ! Flux of fluctuating KE due to mean flow 
        If (compute_quantity(pke_mflux_radial) .or. compute_quantity(pke_mflux_theta) &
            .or. compute_quantity(pke_mflux_phi)) Then

            DO_PSI
                tmp1(PSI) = fbuffer(PSI,vr)**2 + fbuffer(PSI,vtheta)**2 + fbuffer(PSI,vphi)**2
            END_DO
            DO_PSI
                tmp1(PSI) = tmp1(PSI)*half*ref%density(r)
            END_DO

            If (compute_quantity(pke_mflux_radial)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vr)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(pke_mflux_theta)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vtheta)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(pke_mflux_phi)) Then
                DO_PSI
                    qty(PSI) = m0_values(PSI2,vphi)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif

        ! Flux of fluctuating KE due to fluctuating flow 
        If (compute_quantity(pke_pflux_radial) .or. compute_quantity(pke_pflux_theta) &
            .or. compute_quantity(pke_pflux_phi)) Then

            DO_PSI
                tmp1(PSI) = fbuffer(PSI,vr)**2 + fbuffer(PSI,vtheta)**2 + fbuffer(PSI,vphi)**2
            END_DO
            DO_PSI
                tmp1(PSI) = tmp1(PSI)*half*ref%density(r)
            END_DO

            If (compute_quantity(pke_pflux_radial)) Then
                DO_PSI
                    qty(PSI) = fbuffer(PSI,vr)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(pke_pflux_theta)) Then
                DO_PSI
                    qty(PSI) = fbuffer(PSI,vtheta)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(pke_pflux_phi)) Then
                DO_PSI
                    qty(PSI) = fbuffer(PSI,vphi)*tmp1(PSI)
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif


        !/////////////////////////////////////////////////////////////////
        ! Now move on to the viscous fluxes
        !First, the radial viscous flux of energy

        !Note: We use tmp to store v dot D_ij modulo the diagonal terms involving div dot v
        !Store that in tmp1 and then set qty_i = v_j(vr*dlnrhodr+D_ij)

        If (compute_quantity(visc_flux_r) .or. compute_quantity(visc_flux_theta) &
            .or. compute_quantity(visc_flux_phi)) Then
             !Radial contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = buffer(PSI,dvrdr)*buffer(PSI,vr)*2.0d0
            END_DO

            !Theta contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*buffer(PSI,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+buffer(PSI,dvtdr)-buffer(PSI,vtheta)/radius(r)
                tmp1(PSI) = tmp1(PSI)+buffer(PSI,dvrdt)/radius(r)
                tmp1(PSI) = tmp1(PSI)*buffer(PSI,vtheta)
            END_DO            

            !phi contribution (mod rho*nu)
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*buffer(PSI,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+buffer(PSI,dvpdr)-buffer(PSI,vphi)/radius(r)
                tmp1(PSI) = tmp1(PSI)+buffer(PSI,dvrdp)/radius(r)/sintheta(t)
                tmp1(PSI) = tmp1(PSI)*buffer(PSI,vphi)
            END_DO             

            !Multiply by rho and nu
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)*nu(r)*ref%density(r)                            
            END_DO           


            If (compute_quantity(visc_flux_r)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+buffer(PSI,vr)*(buffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

            If (compute_quantity(visc_flux_theta)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+buffer(PSI,vtheta)*(buffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(visc_flux_phi)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+buffer(PSI,vphi)*(buffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif


        If (compute_quantity(visc_fluxpp_r) .or. compute_quantity(visc_fluxpp_theta) &
            .or. compute_quantity(visc_fluxpp_phi)) Then
             !Radial contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = fbuffer(PSI,dvrdr)*fbuffer(PSI,vr)*2.0d0
            END_DO

            !Theta contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*fbuffer(PSI,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+fbuffer(PSI,dvtdr)-fbuffer(PSI,vtheta)/radius(r)
                tmp1(PSI) = tmp1(PSI)+fbuffer(PSI,dvrdt)/radius(r)
                tmp1(PSI) = tmp1(PSI)*fbuffer(PSI,vtheta)
            END_DO            

            !phi contribution (mod rho*nu)
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*fbuffer(PSI,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+fbuffer(PSI,dvpdr)-fbuffer(PSI,vphi)/radius(r)
                tmp1(PSI) = tmp1(PSI)+fbuffer(PSI,dvrdp)/radius(r)/sintheta(t)
                tmp1(PSI) = tmp1(PSI)*fbuffer(PSI,vphi)
            END_DO             

            !Multiply by rho and nu
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)*nu(r)*ref%density(r)                            
            END_DO           


            If (compute_quantity(visc_fluxpp_r)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+fbuffer(PSI,vr)*(fbuffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

            If (compute_quantity(visc_fluxpp_theta)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+fbuffer(PSI,vtheta)*(fbuffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(visc_fluxpp_phi)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+fbuffer(PSI,vphi)*(fbuffer(PSI,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif

        If (compute_quantity(visc_fluxmm_r) .or. compute_quantity(visc_fluxmm_theta) &
            .or. compute_quantity(visc_fluxmm_phi)) Then
             !Radial contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = m0_values(PSI2,dvrdr)*m0_values(PSI2,vr)*2.0d0
            END_DO

            !Theta contribution (mod rho*nu)
            DO_PSI        
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*m0_values(PSI2,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+m0_values(PSI2,dvtdr)-m0_values(PSI2,vtheta)/radius(r)
                tmp1(PSI) = tmp1(PSI)+m0_values(PSI2,dvrdt)/radius(r)
                tmp1(PSI) = tmp1(PSI)*m0_values(PSI2,vtheta)
            END_DO            

            !phi contribution (mod rho*nu)
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)+(2.0d0/3.0d0)*m0_values(PSI2,vr)*ref%dlnrho(r)
                tmp1(PSI) = tmp1(PSI)+m0_values(PSI2,dvpdr)-m0_values(PSI2,vphi)/radius(r)
                tmp1(PSI) = tmp1(PSI)+m0_values(PSI2,dvrdp)/radius(r)/sintheta(t)
                tmp1(PSI) = tmp1(PSI)*m0_values(PSI2,vphi)
            END_DO             

            !Multiply by rho and nu
            DO_PSI            
                tmp1(PSI) = tmp1(PSI)*nu(r)*ref%density(r)                            
            END_DO           


            If (compute_quantity(visc_fluxmm_r)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+m0_values(PSI2,vr)*(m0_values(PSI2,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

            If (compute_quantity(visc_fluxmm_theta)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+m0_values(PSI2,vtheta)*(m0_values(PSI2,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif
            If (compute_quantity(visc_fluxmm_phi)) Then
                DO_PSI
                    qty(PSI) = tmp1(PSI)+m0_values(PSI2,vphi)*(m0_values(PSI2,vr)*ref%dlnrho(r)*one_third )
                END_DO
                Call Add_Quantity(qty)
            Endif

        Endif

        ! Pressure transport terms
        If (compute_quantity(press_flux_r)) Then
            DO_PSI
                qty(PSI)=-buffer(PSI,vr)*buffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_flux_theta)) Then
            DO_PSI
                qty(PSI)=-buffer(PSI,vr)*buffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_flux_phi)) Then
            DO_PSI
                qty(PSI)=-buffer(PSI,vphi)*buffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif


        If (compute_quantity(press_fluxpp_r)) Then
            DO_PSI
                qty(PSI)=-fbuffer(PSI,vr)*fbuffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_fluxpp_theta)) Then
            DO_PSI
                qty(PSI)=-fbuffer(PSI,vr)*fbuffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_fluxpp_phi)) Then
            DO_PSI
                qty(PSI)=-fbuffer(PSI,vphi)*fbuffer(PSI,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif

        If (compute_quantity(press_fluxmm_r)) Then
            DO_PSI
                qty(PSI)=-m0_values(PSI2,vr)*m0_values(PSI2,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_fluxmm_theta)) Then
            DO_PSI
                qty(PSI)=-m0_values(PSI2,vr)*m0_values(PSI2,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif
        If (compute_quantity(press_fluxmm_phi)) Then
            DO_PSI
                qty(PSI)=-m0_values(PSI2,vphi)*m0_values(PSI2,pvar)
            END_DO
            Call Add_Quantity(qty)
        Endif

        ! Shear Production of turbulent kinetic energy.
        !       P_T = -rho_bar uu : E
        If (compute_quantity(production_shear_KE)) Then
            DO_PSI
                one_over_rsin = one_over_r(r) * csctheta(t)
                ctn_over_r = one_over_r(r) * cottheta(t)

                ! Compute elements of the mean rate of strain tensor E_ij
                Err = buffer(PSI,dvrdr)
                Ett = one_over_r(r) * (buffer(PSI,dvtdt) + buffer(PSI,vr))
                Epp = one_over_rsin * buffer(PSI,dvpdp) + ctn_over_r*buffer(PSI,vtheta)    &
                    + one_over_r(r) * buffer(PSI,vr)

                ! Twice the diagonal elements, e.g.,  Ert = 2 * E_rt
                Ert = one_over_r(r) * (buffer(PSI,dvrdt) - buffer(PSI,vtheta))        &
                    + buffer(PSI,dvtdr)    
                Erp = buffer(PSI,dvpdr) + one_over_rsin * buffer(PSI,dvrdp)        &
                    - one_over_r(r) * buffer(PSI,vphi)
                Etp = one_over_rsin * buffer(PSI,dvtdp) - ctn_over_r * buffer(PSI,vphi)    &
                    + one_over_r(r) * buffer(PSI,dvpdt)

                ! Compute u'_i u'_j E_ij
                !DO k = 1, n_phi
                    ! Compute diagonal elements of the double contraction
                    htmp1 = buffer(PSI,vr)**2 * Err
                        htmp2 = buffer(PSI,vtheta)**2 * Ett
                    htmp3 = buffer(PSI,vphi)**2 * Epp
                            qty(PSI) = htmp1 + htmp2 + htmp3

                    ! Compute off-diagonal elements
                    htmp1 = buffer(PSI,vr)*buffer(PSI,vtheta)*Ert
                    htmp2 = buffer(PSI,vr)*buffer(PSI,vphi)*Erp
                    htmp3 = buffer(PSI,vtheta)*buffer(PSI,vphi)*Etp
                    qty(PSI) = qty(PSI) + htmp1 + htmp2 + htmp3

                    qty(PSI) = -ref%density(r) * qty(PSI)
                !ENDDO        ! End of phi loop
             END_DO       ! End of theta & r loop
                Call Add_Quantity(qty)  
        Endif



        ! Shear Production of mean kinetic energy.
        !       P_T = -rho_bar <u><u> : E
        If (compute_quantity(production_shear_mKE)) Then
            DO_PSI2
                one_over_rsin = one_over_r(r) * csctheta(t)
                ctn_over_r = one_over_r(r) * cottheta(t)

                ! Compute elements of the mean rate of strain tensor E_ij
                Err = m0_values(PSI2,dvrdr)
                Ett = one_over_r(r) * (m0_values(PSI2,dvtdt) + m0_values(PSI2,vr))
                Epp = one_over_rsin * m0_values(PSI2,dvpdp) + ctn_over_r*m0_values(PSI2,vtheta)    &
                    + one_over_r(r) * m0_values(PSI2,vr)

                ! Twice the diagonal elements, e.g.,  Ert = 2 * E_rt
                Ert = one_over_r(r) * (m0_values(PSI2,dvrdt) - m0_values(PSI2,vtheta))        &
                    + m0_values(PSI2,dvtdr)    
                Erp = m0_values(PSI2,dvpdr) + one_over_rsin * m0_values(PSI2,dvrdp)        &
                    - one_over_r(r) * m0_values(PSI2,vphi)
                Etp = one_over_rsin * m0_values(PSI2,dvtdp) - ctn_over_r * m0_values(PSI2,vphi)    &
                    + one_over_r(r) * m0_values(PSI2,dvpdt)

                ! Compute u'_i u'_j E_ij
                DO k = 1, n_phi
                    ! Compute diagonal elements of the double contraction
                    htmp1 = m0_values(PSI2,vr)**2 * Err
                        htmp2 = m0_values(PSI2,vtheta)**2 * Ett
                    htmp3 = m0_values(PSI2,vphi)**2 * Epp
                            qty(PSI) = htmp1 + htmp2 + htmp3

                    ! Compute off-diagonal elements
                    htmp1 = m0_values(PSI2,vr)*m0_values(PSI2,vtheta)*Ert
                    htmp2 = m0_values(PSI2,vr)*m0_values(PSI2,vphi)*Erp
                    htmp3 = m0_values(PSI2,vtheta)*m0_values(PSI2,vphi)*Etp
                    qty(PSI) = qty(PSI) + htmp1 + htmp2 + htmp3

                    qty(PSI) = -ref%density(r) * qty(PSI)
                ENDDO        ! End of phi loop
                END_DO2        ! End of theta & r loop
                Call Add_Quantity(qty)  
        Endif
        ! Shear Production of turbulent kinetic energy.
        !       P_T = -rho_bar u'u' : <E>
        If (compute_quantity(production_shear_pKE)) Then
            DO_PSI2
                one_over_rsin = one_over_r(r) * csctheta(t)
                ctn_over_r = one_over_r(r) * cottheta(t)

                ! Compute elements of the mean rate of strain tensor E_ij
                Err = m0_values(PSI2,dvrdr)
                Ett = one_over_r(r) * (m0_values(PSI2,dvtdt) + m0_values(PSI2,vr))
                Epp = one_over_rsin * m0_values(PSI2,dvpdp) + ctn_over_r*m0_values(PSI2,vtheta)    &
                    + one_over_r(r) * m0_values(PSI2,vr)

                ! Twice the diagonal elements, e.g.,  Ert = 2 * E_rt
                Ert = one_over_r(r) * (m0_values(PSI2,dvrdt) - m0_values(PSI2,vtheta))        &
                    + m0_values(PSI2,dvtdr)    
                Erp = m0_values(PSI2,dvpdr) + one_over_rsin * m0_values(PSI2,dvrdp)        &
                    - one_over_r(r) * m0_values(PSI2,vphi)
                Etp = one_over_rsin * m0_values(PSI2,dvtdp) - ctn_over_r * m0_values(PSI2,vphi)    &
                    + one_over_r(r) * m0_values(PSI2,dvpdt)

                ! Compute u'_i u'_j E_ij
                DO k = 1, n_phi
                    ! Compute diagonal elements of the double contraction
                    htmp1 = fbuffer(PSI,vr)**2 * Err
                        htmp2 = fbuffer(PSI,vtheta)**2 * Ett
                    htmp3 = fbuffer(PSI,vphi)**2 * Epp
                            qty(PSI) = htmp1 + htmp2 + htmp3

                    ! Compute off-diagonal elements
                    htmp1 = fbuffer(PSI,vr)*fbuffer(PSI,vtheta)*Ert
                    htmp2 = fbuffer(PSI,vr)*fbuffer(PSI,vphi)*Erp
                    htmp3 = fbuffer(PSI,vtheta)*fbuffer(PSI,vphi)*Etp
                    qty(PSI) = qty(PSI) + htmp1 + htmp2 + htmp3

                    qty(PSI) = -ref%density(r) * qty(PSI)
                ENDDO        ! End of phi loop
                END_DO2        ! End of theta & r loop
                Call Add_Quantity(qty)  
        Endif


    End Subroutine Compute_KE_Flux

End Module Diagnostics_KE_Flux

