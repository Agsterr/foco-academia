package br.com.focodev.academia.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class AppReleaseServiceTest {

    @Test
    void parseAppVersionCode_extractsBuildNumber() {
        assertEquals(16, AppReleaseService.parseAppVersionCode("1.0.1+16"));
        assertNull(AppReleaseService.parseAppVersionCode("1.0.1"));
        assertNull(AppReleaseService.parseAppVersionCode(null));
    }
}
