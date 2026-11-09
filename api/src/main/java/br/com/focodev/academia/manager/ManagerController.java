package br.com.focodev.academia.manager;

import br.com.focodev.academia.manager.ManagerDtos.*;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.LoginRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Cadastro de academia/instrutor autônomo e painel do gestor. */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ManagerController {

    private final ManagerService managerService;
    private final LoginRateLimiter loginRateLimiter;

    @PostMapping("/auth/register-business")
    public RegisterBusinessResponse register(@Valid @RequestBody RegisterBusinessRequest request,
                                             HttpServletRequest httpRequest) {
        loginRateLimiter.check(httpRequest);
        return managerService.register(request);
    }

    @GetMapping("/manager/access")
    public Access access(@AuthenticationPrincipal AuthUser user) {
        return managerService.access(user);
    }

    @GetMapping("/manager/dashboard")
    public Dashboard dashboard(@AuthenticationPrincipal AuthUser user) {
        return managerService.dashboard(user);
    }

    @GetMapping("/manager/instructors")
    public List<InstructorStats> instructors(@AuthenticationPrincipal AuthUser user) {
        return managerService.instructors(user);
    }

    @PostMapping("/manager/instructors")
    public InstructorStats createInstructor(@AuthenticationPrincipal AuthUser user,
                                            @Valid @RequestBody CreatePersonRequest request) {
        return managerService.createInstructor(user, request);
    }

    @GetMapping("/manager/students")
    public List<StudentStats> students(@AuthenticationPrincipal AuthUser user) {
        return managerService.students(user);
    }

    @PostMapping("/manager/students")
    public StudentStats createStudent(@AuthenticationPrincipal AuthUser user,
                                      @Valid @RequestBody CreatePersonRequest request) {
        return managerService.createStudent(user, request);
    }

    @PutMapping("/manager/students/{id}/instructor")
    public StudentStats assignInstructor(@AuthenticationPrincipal AuthUser user, @PathVariable UUID id,
                                         @Valid @RequestBody AssignInstructorRequest request) {
        return managerService.assignInstructor(user, id, request.instructorId());
    }

    @PostMapping("/manager/members/{id}/active")
    public ResponseEntity<Void> setActive(@AuthenticationPrincipal AuthUser user, @PathVariable UUID id,
                                          @RequestParam boolean value) {
        managerService.setActive(user, id, value);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/manager/ratings")
    public List<RatingEntry> ratings(@AuthenticationPrincipal AuthUser user) {
        return managerService.ratings(user);
    }

    @GetMapping("/manager/suggestions")
    public List<SuggestionEntry> suggestions(@AuthenticationPrincipal AuthUser user) {
        return managerService.suggestions(user);
    }

    @PostMapping("/manager/suggestions/{id}/respond")
    public SuggestionEntry respond(@AuthenticationPrincipal AuthUser user, @PathVariable UUID id,
                                   @Valid @RequestBody RespondRequest request) {
        return managerService.respond(user, id, request.response());
    }

    /** "Meus alunos" do instrutor de academia, com atividade e média das notas. */
    @GetMapping("/instructor/students/overview")
    public List<StudentStats> myStudents(@AuthenticationPrincipal AuthUser user) {
        return managerService.studentsOfInstructor(user);
    }
}
