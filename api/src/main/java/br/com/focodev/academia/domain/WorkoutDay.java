package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "workout_days")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutDay {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "program_id")
    private WorkoutProgram program;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private WeekDay weekDay;

    @Column(length = 200)
    private String muscleGroup;

    @Column(length = 1000)
    private String notes;

    @Column(nullable = false)
    private boolean restDay;

    @Column(nullable = false)
    private int sortOrder;

    @OneToMany(mappedBy = "workoutDay", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<Exercise> exercises = new ArrayList<>();
}
