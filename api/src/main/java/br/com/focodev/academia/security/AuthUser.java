package br.com.focodev.academia.security;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public class AuthUser implements UserDetails {

    private final UUID id;
    private final String email;
    private final String password;
    private final UserRole role;
    private final UUID academyId;
    private final boolean academyActive;
    private final boolean academyAppBlocked;
    private final boolean active;

    public AuthUser(User user) {
        this.id = user.getId();
        this.email = user.getEmail();
        this.password = user.getPasswordHash();
        this.role = user.getRole();
        this.academyId = user.getAcademy() != null ? user.getAcademy().getId() : null;
        this.academyActive = user.getAcademy() == null || user.getAcademy().isActive();
        this.academyAppBlocked = user.getAcademy() != null && user.getAcademy().isAppBlocked();
        this.active = user.isActive();
    }

    public UUID getAcademyId() {
        return academyId;
    }

    public boolean isAcademyActive() {
        return academyActive;
    }

    public boolean isAcademyAppBlocked() {
        return academyAppBlocked;
    }

    public UUID getId() {
        return id;
    }

    public UserRole getRole() {
        return role;
    }

    @Override
    public Collection<SimpleGrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return active;
    }
}
